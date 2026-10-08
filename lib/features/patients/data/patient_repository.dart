import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/enums.dart';
import '../../../core/sync/hlc.dart';
import '../../../core/sync/outbox_repository.dart';
import '../domain/new_patient.dart';

/// Patients: reads are drift streams; registering writes the household and
/// the patient locally with their outbox rows in one transaction.
class PatientRepository {
  PatientRepository(
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

  Stream<List<Patient>> watchAll() =>
      (_db.select(_db.patients)
            ..where((p) => p.deleted.equals(false))
            ..orderBy([(p) => OrderingTerm.asc(p.fullName)]))
          .watch();

  /// Marks a patient active or inactive. Queued as its own edit so it merges
  /// field by field with whatever another nurse changed while offline.
  Future<void> setAccountStatus(String id, AccountStatus status) async {
    final stamp = _clock.next();
    await _db.transaction(() async {
      final patient = await (_db.select(
        _db.patients,
      )..where((p) => p.id.equals(id))).getSingle();
      if (patient.accountStatus == status) return;
      await (_db.update(_db.patients)..where((p) => p.id.equals(id))).write(
        PatientsCompanion(
          accountStatus: Value(status),
          syncState: const Value(SyncState.pending),
          hlc: Value(stamp),
        ),
      );
      await _outbox.enqueue(
        entityType: 'patient',
        entityId: id,
        op: ChangeOp.edited,
        label: 'Patient: ${patient.fullName}',
        fields: {'accountStatus': status.name},
        hlc: stamp,
        now: _now(),
      );
    });
    _nudge();
  }

  /// Saves a new household and patient. The household is queued first so the
  /// server has it before the patient that points at it.
  Future<String> register(NewPatient input) async {
    if (!input.isValid) {
      throw ArgumentError(
        'A patient needs a name, a location and a valid phone number.',
      );
    }
    const uuid = Uuid();
    final householdId = uuid.v7();
    final patientId = uuid.v7();
    await _db.transaction(() async {
      final householdStamp = _clock.next();
      await _db
          .into(_db.households)
          .insert(
            HouseholdsCompanion.insert(
              id: householdId,
              hlc: householdStamp,
              headName: input.headName,
              location: input.location,
              syncState: const Value(SyncState.pending),
            ),
          );
      await _outbox.enqueue(
        entityType: 'household',
        entityId: householdId,
        op: ChangeOp.added,
        label: 'Household: ${input.headName}',
        fields: {'headName': input.headName, 'location': input.location},
        hlc: householdStamp,
        now: _now(),
      );
      final patientStamp = _clock.next();
      await _db
          .into(_db.patients)
          .insert(
            PatientsCompanion.insert(
              id: patientId,
              hlc: patientStamp,
              fullName: input.fullName,
              householdId: Value(householdId),
              phoneNumber: Value(input.phoneNumber),
              accountStatus: Value(input.accountStatus),
              syncState: const Value(SyncState.pending),
            ),
          );
      await _outbox.enqueue(
        entityType: 'patient',
        entityId: patientId,
        op: ChangeOp.added,
        label: 'Patient: ${input.fullName}',
        fields: {
          'fullName': input.fullName,
          'householdId': householdId,
          if (input.phoneNumber != null) 'phoneNumber': input.phoneNumber,
          'accountStatus': input.accountStatus.name,
        },
        hlc: patientStamp,
        now: _now(),
      );
    });
    _nudge();
    return patientId;
  }
}
