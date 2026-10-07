import '../db/app_database.dart';
import 'fake_api_client.dart';

/// Mirrors the demo data the phone already holds onto the in-memory server,
/// so edits to seeded visits have something to land on.
Future<void> mirrorLocalDataToFakeServer(
  FakeApiClient server,
  AppDatabase db,
) async {
  for (final h in await db.select(db.households).get()) {
    server.load('household', h.id, {
      'headName': h.headName,
      'location': h.location,
    });
  }
  for (final p in await db.select(db.patients).get()) {
    server.load('patient', p.id, {
      'fullName': p.fullName,
      'householdId': p.householdId,
    });
  }
  for (final v in await db.select(db.visits).get()) {
    server.load('visit', v.id, {
      'patientId': v.patientId,
      'patientName': v.patientName,
      'visitType': v.visitType,
      'scheduledAt': v.scheduledAt.toUtc().toIso8601String(),
    });
  }
}
