import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/enums.dart';
import '../../../core/db/providers.dart';
import '../../../core/network/fake_api_client.dart';

const _tablet = 'Clinic Tablet 2';

/// Debug only: the next sync will deliver a temperature reading "from another
/// tablet" for the first visit that has vitals.
Future<String> injectRemoteTemperature(WidgetRef ref, FakeApiClient api) async {
  final db = ref.read(databaseProvider);
  final vitals = await db.select(db.vitals).get();
  if (vitals.isEmpty) return 'Record vitals on a visit first.';
  api.injectRemoteEdit(
    entityType: 'vitals',
    entityId: vitals.first.id,
    fields: {'temperatureC': 37.9},
    source: _tablet,
  );
  return 'Queued a temperature edit from $_tablet. Sync to receive it.';
}

/// Debug only: a visit-type change "from another tablet" (a merge when you
/// edited a different field).
Future<String> injectRemoteVisitType(WidgetRef ref, FakeApiClient api) async {
  final db = ref.read(databaseProvider);
  final visits = await db.select(db.visits).get();
  if (visits.isEmpty) return 'No visits on the phone.';
  api.injectRemoteEdit(
    entityType: 'visit',
    entityId: visits.first.id,
    fields: {'visitType': 'Follow-up visit'},
    source: _tablet,
  );
  return 'Queued a visit type edit from $_tablet. Sync to receive it.';
}

/// Debug only: another tablet flips the first patient's account status, to
/// try an offline status conflict (mark one inactive here first, offline).
Future<String> injectRemoteAccountStatus(
  WidgetRef ref,
  FakeApiClient api,
) async {
  final db = ref.read(databaseProvider);
  final patients = await db.select(db.patients).get();
  if (patients.isEmpty) return 'No patients on the phone.';
  final p = patients.first;
  final flipped = p.accountStatus == AccountStatus.active
      ? AccountStatus.inactive
      : AccountStatus.active;
  api.injectRemoteEdit(
    entityType: 'patient',
    entityId: p.id,
    fields: {'accountStatus': flipped.name},
    source: _tablet,
  );
  return 'Queued ${flipped.name} for ${p.fullName} from $_tablet. Sync to receive it.';
}

/// Debug only: another tablet deletes the first visit.
Future<String> injectRemoteDelete(WidgetRef ref, FakeApiClient api) async {
  final db = ref.read(databaseProvider);
  final visits = await db.select(db.visits).get();
  if (visits.isEmpty) return 'No visits on the phone.';
  api.injectRemoteEdit(
    entityType: 'visit',
    entityId: visits.first.id,
    fields: const {},
    op: ChangeOp.deleted,
    source: _tablet,
  );
  return 'Queued a delete from $_tablet. Sync to receive it.';
}
