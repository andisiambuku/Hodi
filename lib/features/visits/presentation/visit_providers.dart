import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/providers.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/sync/sync_providers.dart';
import '../../patients/data/patient_repository.dart';
import '../../vitals/data/vitals_repository.dart';
import '../data/visit_repository.dart';

final visitRepositoryProvider = Provider<VisitRepository>(
  (ref) => VisitRepository(
    ref.watch(databaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(hlcClockProvider),
    nudge: ref.read(syncEngineProvider).nudge,
  ),
);

/// Today's visits, live from the local DB.
final todaysVisitsProvider = StreamProvider<List<Visit>>(
  (ref) => ref.watch(visitRepositoryProvider).watchDay(DateTime.now()),
);

final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => PatientRepository(
    ref.watch(databaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(hlcClockProvider),
    nudge: ref.read(syncEngineProvider).nudge,
  ),
);

final patientsProvider = StreamProvider<List<Patient>>(
  (ref) => ref.watch(patientRepositoryProvider).watchAll(),
);

final vitalsRepositoryProvider = Provider<VitalsRepository>(
  (ref) => VitalsRepository(
    ref.watch(databaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(hlcClockProvider),
    nudge: ref.read(syncEngineProvider).nudge,
  ),
);

final visitProvider = StreamProvider.family<Visit?, String>(
  (ref, id) => ref.watch(visitRepositoryProvider).watchById(id),
);

final vitalsForVisitProvider = StreamProvider.family<Vital?, String>(
  (ref, visitId) => ref.watch(vitalsRepositoryProvider).watchForVisit(visitId),
);
