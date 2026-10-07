import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/enums.dart';

const _uuid = Uuid();

/// The durable queue of local changes.
///
/// [enqueue] must be called inside the same `db.transaction` that writes the
/// entity row, so a change can never be saved without being queued.
class OutboxRepository {
  OutboxRepository(this._db);

  final AppDatabase _db;

  /// Everything not yet acked, oldest first (the order it will be sent in).
  /// Failed entries stay visible so the nurse can see what was rejected.
  Stream<List<OutboxEntry>> watchPending() =>
      (_db.select(_db.outbox)
            ..where((o) => o.status.equalsValue(OutboxStatus.acked).not())
            ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
          .watch();

  /// Queued or in-flight entries (excludes rejected ones).
  Stream<int> watchSendableCount() =>
      (_db.select(_db.outbox)..where(
            (o) =>
                o.status.equalsValue(OutboxStatus.queued) |
                o.status.equalsValue(OutboxStatus.inFlight),
          ))
          .watch()
          .map((l) => l.length);

  /// Drops every not-yet-acked entry for an entity (used when the server's
  /// version of events replaces ours).
  Future<void> removeUnacked(String entityType, String entityId) =>
      (_db.delete(_db.outbox)..where(
            (o) =>
                o.entityType.equals(entityType) &
                o.entityId.equals(entityId) &
                o.status.equalsValue(OutboxStatus.acked).not(),
          ))
          .go();

  /// True if the entity has any change the server hasn't acknowledged.
  Future<bool> hasUnacked(String entityType, String entityId) async {
    final rows =
        await (_db.select(_db.outbox)
              ..where(
                (o) =>
                    o.entityType.equals(entityType) &
                    o.entityId.equals(entityId) &
                    o.status.equalsValue(OutboxStatus.acked).not(),
              )
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  Stream<int> watchPendingCount() => watchPending().map((l) => l.length);

  /// Queue a change, folding it into an unsent entry where possible so the
  /// pending list stays short:
  ///
  /// * edit of an entity with an unsent `added`/`edited` entry → merged in;
  /// * delete of an entity whose `added` was never sent → both vanish and the
  ///   caller must hard-delete the entity (returns `true`);
  /// * delete otherwise → drops unsent edits, queues one `deleted`.
  ///
  /// Only `queued` entries are folded; an `inFlight` one may already be on
  /// the wire.
  Future<bool> enqueue({
    required String entityType,
    required String entityId,
    required ChangeOp op,
    required String label,
    required Map<String, Object?> fields,
    required String hlc,
    required DateTime now,
  }) async {
    final open =
        await (_db.select(_db.outbox)
              ..where(
                (o) =>
                    o.entityType.equals(entityType) &
                    o.entityId.equals(entityId) &
                    o.status.equalsValue(OutboxStatus.queued),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
            .get();

    switch (op) {
      case ChangeOp.added:
        await _insert(entityType, entityId, op, label, fields, hlc, now);
        return false;

      case ChangeOp.edited:
        final target = open.where((e) => e.op != ChangeOp.deleted).lastOrNull;
        if (target == null) {
          await _insert(entityType, entityId, op, label, fields, hlc, now);
        } else {
          final merged = _decode(target.payload);
          merged['fields'] = {
            ...(merged['fields'] as Map<String, Object?>),
            ..._stamp(fields, hlc),
          };
          merged['hlc'] = hlc;
          await (_db.update(_db.outbox)..where((o) => o.id.equals(target.id)))
              .write(OutboxCompanion(payload: Value(jsonEncode(merged))));
        }
        return false;

      case ChangeOp.deleted:
        final neverSent = open.any((e) => e.op == ChangeOp.added);
        await (_db.delete(
          _db.outbox,
        )..where((o) => o.id.isIn(open.map((e) => e.id)))).go();
        if (neverSent) return true;
        await _insert(entityType, entityId, op, label, const {}, hlc, now);
        return false;
    }
  }

  Future<void> _insert(
    String entityType,
    String entityId,
    ChangeOp op,
    String label,
    Map<String, Object?> fields,
    String hlc,
    DateTime now,
  ) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          id: _uuid.v7(), // also the Idempotency-Key
          entityType: entityType,
          entityId: entityId,
          op: op,
          label: label,
          payload: jsonEncode({'fields': _stamp(fields, hlc), 'hlc': hlc}),
          createdAt: now,
        ),
      );

  /// Per-field HLC, which the conflict resolver needs for field-level merges.
  Map<String, Object?> _stamp(Map<String, Object?> fields, String hlc) => {
    for (final e in fields.entries) e.key: {'v': e.value, 'hlc': hlc},
  };

  Map<String, Object?> _decode(String payload) {
    final m = jsonDecode(payload) as Map;
    return {
      'fields': Map<String, Object?>.from(m['fields'] as Map),
      'hlc': m['hlc'],
    };
  }
}
