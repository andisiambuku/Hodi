import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/enums.dart';
import '../network/api_client.dart';
import 'change_applier.dart';
import 'entity_schema.dart';
import 'hlc.dart';
import 'outbox_repository.dart';

/// Field-level resolution of a remote change against unsent local edits.
///
/// A local edit that hasn't reached the server can't have been seen by
/// whoever made the remote edit, so any overlap is concurrent by definition.
/// Compared field by field using HLCs:
///
/// | remote vs local                         | outcome                       |
/// |-----------------------------------------|-------------------------------|
/// | different fields                        | both kept, `merged` notice    |
/// | same field, remote newer                | remote kept, `replaced` card  |
/// | same field, local newer, non-clinical   | local kept, nothing shown     |
/// | same field, local newer, **clinical**   | local kept, `localKept` card  |
/// | remote deleted, local edited            | local kept, `deletedRemotely` |
///
/// Clinical values (vitals, medications, results, diagnoses) are never
/// changed or kept without a visible card.
class ConflictResolver implements ChangeApplier {
  ConflictResolver(
    this._db,
    this._outbox,
    this._store,
    this._clock, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final EntityStore _store;
  final HlcClock _clock;
  final DateTime Function() _now;

  @override
  Future<ApplyOutcome> apply(RemoteChange c) async {
    for (final f in c.fields.values) {
      _clock.receive(f.hlc);
    }
    final schema = _store.schemaFor(c.entityType);
    if (schema == null) return ApplyOutcome.plain; // a type we don't know yet

    return _db.transaction(() async {
      final pending = await _pending(c.entityType, c.entityId);
      final local = await _store.read(c.entityType, c.entityId);
      return c.op == ChangeOp.deleted
          ? _remoteDeleted(c, schema, pending, local)
          : _remoteChanged(c, schema, pending, local);
    });
  }

  // ── remote add / edit ───────────────────────────────────────────────

  Future<ApplyOutcome> _remoteChanged(
    RemoteChange c,
    EntitySchema schema,
    List<_Pending> pending,
    LocalRow? local,
  ) async {
    final latest = c.fields.values
        .map((f) => f.hlc)
        .fold('', (a, b) => a.compareTo(b) >= 0 ? a : b);

    if (local == null) {
      final values = {for (final e in c.fields.entries) e.key: e.value.value};
      if (!_hasRequired(schema, values)) {
        return ApplyOutcome.plain; // incomplete: nothing safe to create
      }
      await _store.insert(
        c.entityType,
        c.entityId,
        values,
        hlc: latest,
        serverVersion: c.serverVersion,
      );
      return ApplyOutcome.plain;
    }
    // We deleted it locally; that intent stands and will be pushed.
    if (pending.any((p) => p.op == ChangeOp.deleted)) return ApplyOutcome.plain;

    final mine = _localFields(pending);
    final toApply = <String, Object?>{};
    final remoteOnly = <String>[];
    final replacedAway = <String>{};
    final cards = <_Card>[];

    for (final e in c.fields.entries) {
      final spec = schema.fields[e.key];
      if (spec == null) continue; // create-only fields never conflict
      final theirs = e.value;
      final ours = mine[e.key];
      if (ours == null) {
        toApply[e.key] = theirs.value;
        remoteOnly.add(e.key);
      } else if (_store.sameValue(spec, ours.value, theirs.value)) {
        // Both sides already agree.
      } else if (theirs.hlc.compareTo(ours.hlc) > 0) {
        toApply[e.key] = theirs.value;
        replacedAway.add(e.key);
        cards.add(
          _Card(ConflictKind.replaced, e.key, ours.value, theirs.value),
        );
      } else if (spec.clinical) {
        cards.add(
          _Card(ConflictKind.localKept, e.key, ours.value, theirs.value),
        );
      }
    }

    final merged =
        remoteOnly.isNotEmpty && mine.keys.any((k) => !c.fields.containsKey(k));

    await _store.update(
      c.entityType,
      c.entityId,
      toApply,
      hlc: latest.compareTo(local.hlc) > 0 ? latest : null,
      serverVersion: c.serverVersion,
    );
    if (replacedAway.isNotEmpty) await _dropFromPending(pending, replacedAway);

    final subject = await _store.subject(c.entityType, c.entityId);
    for (final card in cards) {
      final spec = schema.fields[card.field]!;
      await _insertConflict(
        entityType: c.entityType,
        entityId: c.entityId,
        field: card.field,
        fieldLabel: spec.label,
        subject: subject,
        local: card.local,
        remote: card.remote,
        source: c.source,
        unit: spec.unit,
        kind: card.kind,
      );
    }
    if (merged) {
      await _insertConflict(
        entityType: c.entityType,
        entityId: c.entityId,
        field: remoteOnly.join(','),
        fieldLabel: remoteOnly.map((f) => schema.fields[f]!.label).join(', '),
        subject: subject,
        local: null,
        remote: null,
        source: c.source,
        unit: '',
        kind: ConflictKind.merged,
      );
    }
    await _store.refreshState(c.entityType, c.entityId);
    return ApplyOutcome(merged: merged, conflicts: cards.length);
  }

  // ── remote delete ───────────────────────────────────────────────────

  Future<ApplyOutcome> _remoteDeleted(
    RemoteChange c,
    EntitySchema schema,
    List<_Pending> pending,
    LocalRow? local,
  ) async {
    if (local == null) {
      await _removeUnsent(c);
      return ApplyOutcome.plain;
    }
    final edits = pending.where((p) => p.op != ChangeOp.deleted);
    if (edits.isEmpty) {
      // Nothing of ours to protect (or we also deleted it): follow the server.
      await _removeUnsent(c);
      await _store.hardDelete(c.entityType, c.entityId);
      return ApplyOutcome.plain;
    }

    // We edited something that was deleted elsewhere. Keep our version by
    // re-creating it, and ask the nurse.
    final subject = await _store.subject(c.entityType, c.entityId);
    await _removeUnsent(c);
    final stamp = _clock.next();
    await _outbox.enqueue(
      entityType: c.entityType,
      entityId: c.entityId,
      op: ChangeOp.added,
      label: '${schema.labelPrefix}: $subject',
      fields: {
        for (final e in local.values.entries)
          if (e.value != null) e.key: e.value,
      },
      hlc: stamp,
      now: _now(),
    );
    await _store.update(
      c.entityType,
      c.entityId,
      const {},
      deleted: false,
      serverVersion: 0,
      hlc: stamp,
    );
    await _insertConflict(
      entityType: c.entityType,
      entityId: c.entityId,
      field: '',
      fieldLabel: schema.noun,
      subject: subject,
      local: null,
      remote: null,
      source: c.source,
      unit: '',
      kind: ConflictKind.deletedRemotely,
    );
    await _store.refreshState(c.entityType, c.entityId);
    return const ApplyOutcome(conflicts: 1);
  }

  // ── helpers ─────────────────────────────────────────────────────────

  bool _hasRequired(EntitySchema s, Map<String, Object?> values) {
    // Every create-only key plus the fields the table can't do without.
    const required = {
      'visit': ['patientId', 'scheduledAt'],
      'vitals': ['visitId'],
      'patient': ['fullName'],
      'household': ['headName', 'location'],
    };
    return (required[s.type] ?? const []).every((k) => values[k] != null);
  }

  Future<List<_Pending>> _pending(String type, String id) async {
    final rows =
        await (_db.select(_db.outbox)
              ..where(
                (o) =>
                    o.entityType.equals(type) &
                    o.entityId.equals(id) &
                    o.status.equalsValue(OutboxStatus.acked).not(),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
            .get();
    return [
      for (final r in rows)
        _Pending(r.id, r.op, {
          for (final e
              in ((jsonDecode(r.payload) as Map)['fields'] as Map).entries)
            e.key as String: _Stamped(
              (e.value as Map)['v'],
              (e.value as Map)['hlc'] as String,
            ),
        }),
    ];
  }

  /// Latest unsent value (and its HLC) per field.
  Map<String, _Stamped> _localFields(List<_Pending> pending) {
    final out = <String, _Stamped>{};
    for (final p in pending) {
      if (p.op == ChangeOp.deleted) continue;
      out.addAll(p.fields);
    }
    return out;
  }

  Future<void> _dropFromPending(
    List<_Pending> pending,
    Set<String> fields,
  ) async {
    for (final p in pending) {
      if (!p.fields.keys.any(fields.contains)) continue;
      final kept = {
        for (final e in p.fields.entries)
          if (!fields.contains(e.key)) e.key: e.value,
      };
      if (kept.isEmpty && p.op == ChangeOp.edited) {
        await (_db.delete(_db.outbox)..where((o) => o.id.equals(p.id))).go();
      } else {
        final row = await (_db.select(
          _db.outbox,
        )..where((o) => o.id.equals(p.id))).getSingle();
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        payload['fields'] = {
          for (final e in kept.entries)
            e.key: {'v': e.value.value, 'hlc': e.value.hlc},
        };
        await (_db.update(_db.outbox)..where((o) => o.id.equals(p.id))).write(
          OutboxCompanion(payload: Value(jsonEncode(payload))),
        );
      }
    }
  }

  Future<void> _removeUnsent(RemoteChange c) =>
      _outbox.removeUnacked(c.entityType, c.entityId);

  Future<void> _insertConflict({
    required String entityType,
    required String entityId,
    required String field,
    required String fieldLabel,
    required String subject,
    required Object? local,
    required Object? remote,
    required String source,
    required String unit,
    required ConflictKind kind,
  }) => _db
      .into(_db.conflicts)
      .insert(
        ConflictsCompanion.insert(
          id: EntityStore.newId(),
          entityType: entityType,
          entityId: entityId,
          field: field,
          fieldLabel: fieldLabel,
          subjectName: subject,
          localValue: EntityStore.encodeValue(local),
          remoteValue: EntityStore.encodeValue(remote),
          remoteSource: source,
          unit: Value(unit),
          kind: kind,
          createdAt: _now(),
        ),
      );
}

class _Stamped {
  const _Stamped(this.value, this.hlc);

  final Object? value;
  final String hlc;
}

class _Pending {
  const _Pending(this.id, this.op, this.fields);

  final String id;
  final ChangeOp op;
  final Map<String, _Stamped> fields;
}

class _Card {
  const _Card(this.kind, this.field, this.local, this.remote);

  final ConflictKind kind;
  final String field;
  final Object? local;
  final Object? remote;
}
