import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/enums.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/outbox_repository.dart';
import '../domain/new_visit.dart';

/// Visits: reads are drift streams (the UI never reads network responses);
/// every write lands locally first, with its outbox row in the same
/// transaction.
class VisitRepository {
  VisitRepository(
    this._db,
    this._outbox,
    this._clock, {
    void Function()? nudge,
    DateTime Function()? now,
  }) : _nudge = nudge ?? _noop,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final HlcClock _clock;
  final void Function() _nudge;
  final DateTime Function() _now;

  static void _noop() {}

  /// Visits scheduled on [day]'s calendar date, soonest first. Soft-deleted
  /// rows are hidden.
  Stream<List<Visit>> watchDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.visits)
          ..where(
            (v) =>
                v.deleted.equals(false) &
                v.scheduledAt.isBiggerOrEqualValue(start) &
                v.scheduledAt.isSmallerThanValue(end),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.scheduledAt)]))
        .watch();
  }

  Stream<Visit?> watchById(String id) => (_db.select(
    _db.visits,
  )..where((v) => v.id.equals(id))).watchSingleOrNull();

  Future<String> recordVisit(NewVisit input) async {
    final id = const Uuid().v7();
    final stamp = _clock.next();
    await _db.transaction(() async {
      await _db
          .into(_db.visits)
          .insert(
            VisitsCompanion.insert(
              id: id,
              hlc: stamp,
              patientId: input.patientId,
              patientName: input.patientName,
              visitType: input.visitType,
              scheduledAt: input.scheduledAt,
              syncState: const Value(SyncState.pending),
            ),
          );
      await _outbox.enqueue(
        entityType: 'visit',
        entityId: id,
        op: ChangeOp.added,
        label: 'Visit: ${input.patientName}',
        fields: {
          'patientId': input.patientId,
          'patientName': input.patientName,
          'visitType': input.visitType,
          'scheduledAt': input.scheduledAt.toUtc().toIso8601String(),
        },
        hlc: stamp,
        now: _now(),
      );
    });
    _nudge();
    return id;
  }

  Future<void> editVisit(String id, VisitChanges changes) async {
    if (changes.isEmpty) return;
    final stamp = _clock.next();
    await _db.transaction(() async {
      final visit = await (_db.select(
        _db.visits,
      )..where((v) => v.id.equals(id))).getSingle();
      await (_db.update(_db.visits)..where((v) => v.id.equals(id))).write(
        VisitsCompanion(
          visitType: Value.absentIfNull(changes.visitType),
          scheduledAt: Value.absentIfNull(changes.scheduledAt),
          completedAt: Value.absentIfNull(changes.completedAt),
          syncState: const Value(SyncState.pending),
          hlc: Value(stamp),
        ),
      );
      await _outbox.enqueue(
        entityType: 'visit',
        entityId: id,
        op: ChangeOp.edited,
        label: 'Visit: ${visit.patientName}',
        fields: {
          if (changes.visitType != null) 'visitType': changes.visitType,
          if (changes.scheduledAt != null)
            'scheduledAt': changes.scheduledAt!.toUtc().toIso8601String(),
          if (changes.completedAt != null)
            'completedAt': changes.completedAt!.toUtc().toIso8601String(),
        },
        hlc: stamp,
        now: _now(),
      );
    });
    _nudge();
  }

  /// Soft delete. If the server never heard of the visit, it is removed
  /// outright together with its queued entries.
  Future<void> deleteVisit(String id) async {
    final stamp = _clock.next();
    await _db.transaction(() async {
      final visit = await (_db.select(
        _db.visits,
      )..where((v) => v.id.equals(id))).getSingle();
      final purge = await _outbox.enqueue(
        entityType: 'visit',
        entityId: id,
        op: ChangeOp.deleted,
        label: 'Visit: ${visit.patientName}',
        fields: const {},
        hlc: stamp,
        now: _now(),
      );
      if (purge) {
        final vitals = await (_db.select(
          _db.vitals,
        )..where((v) => v.visitId.equals(id))).get();
        for (final v in vitals) {
          await _outbox.enqueue(
            entityType: 'vitals',
            entityId: v.id,
            op: ChangeOp.deleted,
            label: '',
            fields: const {},
            hlc: stamp,
            now: _now(),
          );
        }
        await (_db.delete(_db.vitals)..where((v) => v.visitId.equals(id))).go();
        await (_db.delete(_db.visits)..where((v) => v.id.equals(id))).go();
      } else {
        await (_db.update(_db.visits)..where((v) => v.id.equals(id))).write(
          VisitsCompanion(
            deleted: const Value(true),
            syncState: const Value(SyncState.pending),
            hlc: Value(stamp),
          ),
        );
      }
    });
    _nudge();
  }
}
