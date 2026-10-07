import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'enums.dart';

const _uuid = Uuid();
const _seedHlc = '0000000000000-0000-seed';

/// Demo data from the mockups (spec §8), used until the real API exists.
/// Inserts only into an empty database. Everything is `synced` because it
/// represents data already on the server; pending states must come from real
/// outbox rows, not from seed flags.
Future<void> seedDemoData(AppDatabase db, {DateTime? today}) async {
  final hasVisits = await (db.select(db.visits)..limit(1)).get();
  if (hasVisits.isNotEmpty) return;

  final day = today ?? DateTime.now();
  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  final rows = [
    ('Amina Wanjiru', 'Antenatal check', at(8, 15)),
    ('Joseph Kamau', 'BP follow-up', at(9, 2)),
    ('Grace Njeri', 'Child immunisation', at(9, 40)),
    ('Peter Otieno', 'Malaria test', at(10, 25)),
    ('Mary Achieng', 'Home visit: new household', at(11, 10)),
    ('Daniel Mwangi', 'Diabetes review', at(11, 55)),
  ];

  await db.transaction(() async {
    for (final (name, type, time) in rows) {
      final householdId = _uuid.v7();
      final patientId = _uuid.v7();
      await db
          .into(db.households)
          .insert(
            HouseholdsCompanion.insert(
              id: householdId,
              hlc: _seedHlc,
              headName: name,
              location: 'Kinangop',
              syncState: const Value(SyncState.synced),
              serverVersion: const Value(1),
            ),
          );
      await db
          .into(db.patients)
          .insert(
            PatientsCompanion.insert(
              id: patientId,
              hlc: _seedHlc,
              fullName: name,
              householdId: Value(householdId),
              syncState: const Value(SyncState.synced),
              serverVersion: const Value(1),
            ),
          );
      await db
          .into(db.visits)
          .insert(
            VisitsCompanion.insert(
              id: _uuid.v7(),
              hlc: _seedHlc,
              patientId: patientId,
              patientName: name,
              visitType: type,
              scheduledAt: time,
              syncState: const Value(SyncState.synced),
              serverVersion: const Value(1),
            ),
          );
    }
  });
}
