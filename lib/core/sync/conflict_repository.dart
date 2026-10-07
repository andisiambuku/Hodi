import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/enums.dart';
import 'entity_schema.dart';
import 'hlc.dart';
import 'outbox_repository.dart';

/// Reads unresolved conflicts and carries out the nurse's choices. Every
/// write goes through the outbox like any other edit.
class ConflictRepository {
  ConflictRepository(
    this._db,
    this._outbox,
    this._store,
    this._clock, {
    void Function()? nudge,
    DateTime Function()? now,
  }) : _nudge = nudge ?? _noop,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final EntityStore _store;
  final HlcClock _clock;
  final void Function() _nudge;
  final DateTime Function() _now;

  static void _noop() {}

  /// Merge notices and conflict cards not yet acted on. Survives restarts.
  Stream<List<Conflict>> watchUnresolved() =>
      (_db.select(_db.conflicts)
            ..where((c) => c.resolved.equals(false))
            ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
          .watch();

  Future<Conflict> _get(String id) =>
      (_db.select(_db.conflicts)..where((c) => c.id.equals(id))).getSingle();

  Future<void> _markResolved(String id) =>
      (_db.update(_db.conflicts)..where((c) => c.id.equals(id))).write(
        const ConflictsCompanion(resolved: Value(true)),
      );

  /// Dismiss a merge notice, or accept the value that is already in place
  /// ("Keep newer" / "Keep mine" / "Keep my version"). No data changes.
  Future<void> accept(String id) => _db.transaction(() async {
    final c = await _get(id);
    await _markResolved(id);
    if (_store.schemaFor(c.entityType) != null) {
      await _store.refreshState(c.entityType, c.entityId);
    }
  });

  /// "Re-enter mine": write the nurse's replaced value back as a new edit.
  Future<void> reenterMine(String id) async {
    await _writeAsNewEdit(id, (c) => EntityStore.decodeValue(c.localValue));
    _nudge();
  }

  /// For `localKept`: take the other device's value instead, as a new edit.
  Future<void> useTheirs(String id) async {
    await _writeAsNewEdit(id, (c) => EntityStore.decodeValue(c.remoteValue));
    _nudge();
  }

  Future<void> _writeAsNewEdit(String id, Object? Function(Conflict) pick) =>
      _db.transaction(() async {
        final c = await _get(id);
        final schema = _store.schemaFor(c.entityType);
        final value = pick(c);
        if (schema != null && schema.fields.containsKey(c.field)) {
          final stamp = _clock.next();
          await _store.update(c.entityType, c.entityId, {
            c.field: value,
          }, hlc: stamp);
          await _outbox.enqueue(
            entityType: c.entityType,
            entityId: c.entityId,
            op: ChangeOp.edited,
            label: '${schema.labelPrefix}: ${c.subjectName}',
            fields: {c.field: value},
            hlc: stamp,
            now: _now(),
          );
        }
        await _markResolved(id);
        await _store.refreshState(c.entityType, c.entityId);
      });

  /// For `deletedRemotely`: agree with the deletion after all.
  Future<void> deleteIt(String id) async {
    await _db.transaction(() async {
      final c = await _get(id);
      final schema = _store.schemaFor(c.entityType);
      if (schema != null) {
        final stamp = _clock.next();
        final purge = await _outbox.enqueue(
          entityType: c.entityType,
          entityId: c.entityId,
          op: ChangeOp.deleted,
          label: '${schema.labelPrefix}: ${c.subjectName}',
          fields: const {},
          hlc: stamp,
          now: _now(),
        );
        if (purge) {
          await _store.hardDelete(c.entityType, c.entityId);
        } else {
          await _store.update(
            c.entityType,
            c.entityId,
            const {},
            deleted: true,
            hlc: stamp,
          );
        }
      }
      await _markResolved(id);
      if (schema != null) await _store.refreshState(c.entityType, c.entityId);
    });
    _nudge();
  }
}
