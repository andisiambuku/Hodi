import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/enums.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/outbox_repository.dart';

/// Vitals for a visit. Clinical data: edits go through the outbox like any
/// other change, and the resolver will never overwrite them silently.
class VitalsRepository {
  VitalsRepository(
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

  Stream<Vital?> watchForVisit(String visitId) =>
      (_db.select(_db.vitals)
            ..where((v) => v.visitId.equals(visitId) & v.deleted.equals(false))
            ..limit(1))
          .watchSingleOrNull();

  /// Saves vitals for a visit: creates the record the first time, then edits
  /// only the fields that changed. Null arguments mean "leave as is".
  Future<void> save(
    String visitId, {
    double? temperatureC,
    int? systolic,
    int? diastolic,
  }) async {
    final stamp = _clock.next();
    await _db.transaction(() async {
      final visit = await (_db.select(
        _db.visits,
      )..where((v) => v.id.equals(visitId))).getSingle();
      final existing =
          await (_db.select(_db.vitals)
                ..where(
                  (v) => v.visitId.equals(visitId) & v.deleted.equals(false),
                )
                ..limit(1))
              .getSingleOrNull();
      final label = 'Vitals: ${visit.patientName}';

      if (existing == null) {
        final id = const Uuid().v7();
        await _db
            .into(_db.vitals)
            .insert(
              VitalsCompanion.insert(
                id: id,
                hlc: stamp,
                visitId: visitId,
                temperatureC: Value(temperatureC),
                systolic: Value(systolic),
                diastolic: Value(diastolic),
                syncState: const Value(SyncState.pending),
              ),
            );
        await _outbox.enqueue(
          entityType: 'vitals',
          entityId: id,
          op: ChangeOp.added,
          label: label,
          fields: {
            'visitId': visitId,
            'temperatureC': ?temperatureC,
            'systolic': ?systolic,
            'diastolic': ?diastolic,
          },
          hlc: stamp,
          now: _now(),
        );
        return;
      }

      final changed = <String, Object?>{
        if (temperatureC != null && temperatureC != existing.temperatureC)
          'temperatureC': temperatureC,
        if (systolic != null && systolic != existing.systolic)
          'systolic': systolic,
        if (diastolic != null && diastolic != existing.diastolic)
          'diastolic': diastolic,
      };
      if (changed.isEmpty) return;
      await (_db.update(
        _db.vitals,
      )..where((v) => v.id.equals(existing.id))).write(
        VitalsCompanion(
          temperatureC: Value.absentIfNull(temperatureC),
          systolic: Value.absentIfNull(systolic),
          diastolic: Value.absentIfNull(diastolic),
          syncState: const Value(SyncState.pending),
          hlc: Value(stamp),
        ),
      );
      await _outbox.enqueue(
        entityType: 'vitals',
        entityId: existing.id,
        op: ChangeOp.edited,
        label: label,
        fields: changed,
        hlc: stamp,
        now: _now(),
      );
    });
    _nudge();
  }
}
