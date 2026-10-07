import 'dart:async';

import 'package:drift/native.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/core/network/api_client.dart';
import 'package:hodi/core/network/fake_api_client.dart';
import 'package:hodi/core/network/fake_server_seed.dart';
import 'package:hodi/core/sync/conflict_repository.dart';
import 'package:hodi/core/sync/conflict_resolver.dart';
import 'package:hodi/core/sync/entity_schema.dart';
import 'package:hodi/features/vitals/data/vitals_repository.dart';
import 'package:hodi/core/sync/hlc.dart';
import 'package:hodi/core/sync/outbox_repository.dart';
import 'package:hodi/core/sync/sync_engine.dart';
import 'package:hodi/core/sync/sync_meta_repository.dart';
import 'package:hodi/core/sync/sync_progress.dart';
import 'package:hodi/features/patients/data/patient_repository.dart';
import 'package:hodi/features/visits/data/visit_repository.dart';
import 'package:hodi/features/visits/domain/new_visit.dart';

/// Records each push batch so tests can assert batching and order.
class RecordingApi extends FakeApiClient {
  RecordingApi({super.now}) : super(latency: Duration.zero);

  final batches = <List<PushItem>>[];

  /// Makes only `changes()` fail, to test a pull failing after a good push.
  bool breakChanges = false;

  /// Makes only `push()` fail, to test a push failing after a good pull.
  bool breakPush = false;

  /// The server applies the push, then the response never arrives: what a
  /// killed app looks like from the server's side.
  bool hangAfterApply = false;

  /// The request never reaches the server and never returns.
  bool hangBeforeApply = false;

  @override
  Future<ChangesPage> changes({String? since, required String deviceId}) {
    if (breakChanges) throw const ServerException();
    return super.changes(since: since, deviceId: deviceId);
  }

  @override
  Future<List<PushResult>> push(
    List<PushItem> items, {
    required String deviceId,
    required String source,
  }) {
    if (breakPush) throw const ServerException();
    if (hangBeforeApply) return Completer<List<PushResult>>().future;
    batches.add(items);
    final applied = super.push(items, deviceId: deviceId, source: source);
    if (!hangAfterApply) return applied;
    return applied.then((_) => Completer<List<PushResult>>().future);
  }
}

class SyncHarness {
  SyncHarness._();

  late AppDatabase db;
  late RecordingApi api;
  late OutboxRepository outbox;
  late VisitRepository visits;
  late PatientRepository patients;
  late VitalsRepository vitals;
  late ConflictRepository conflicts;
  late EntityStore store;
  late SyncEngine engine;
  late SyncMetaRepository meta;
  late HlcClock clock;
  bool online = true;
  DateTime now = DateTime(2026, 10, 6, 9);

  /// The fake server's clock. Set later than [now] to make remote edits newer.
  DateTime remoteNow = DateTime(2026, 10, 6, 10);
  final progress = <SyncProgress?>[];

  /// [db] and [api] can be supplied to model a second app run over the same
  /// storage and server (set [seed] false when the DB already has data).
  static Future<SyncHarness> create({
    int batchSize = 20,
    AppDatabase? db,
    RecordingApi? api,
    bool seed = true,
    bool Function()? isOnline,
  }) async {
    final h = SyncHarness._();
    h.db = db ?? AppDatabase(NativeDatabase.memory());
    h.api = api ?? RecordingApi(now: () => h.remoteNow);
    h.outbox = OutboxRepository(h.db);
    h.clock = HlcClock(nodeId: 'dev1', now: () => h.now);
    h.meta = SyncMetaRepository(h.db);
    h.store = EntityStore(h.db);
    h.visits = VisitRepository(h.db, h.outbox, h.clock, now: () => h.now);
    h.patients = PatientRepository(h.db, h.outbox, h.clock, now: () => h.now);
    h.vitals = VitalsRepository(h.db, h.outbox, h.clock, now: () => h.now);
    h.conflicts = ConflictRepository(
      h.db,
      h.outbox,
      h.store,
      h.clock,
      now: () => h.now,
    );
    h.engine = SyncEngine(
      db: h.db,
      api: h.api,
      applier: ConflictResolver(
        h.db,
        h.outbox,
        h.store,
        h.clock,
        now: () => h.now,
      ),
      meta: h.meta,
      deviceId: 'dev1',
      isOnline: isOnline ?? () => h.online,
      onProgress: h.progress.add,
      batchSize: batchSize,
      now: () => h.now,
    );
    if (seed) {
      await seedDemoData(h.db, today: DateTime(2026, 10, 6));
      await mirrorLocalDataToFakeServer(h.api, h.db);
    }
    return h;
  }

  Future<String> recordVisit([String type = 'Malaria test']) async {
    final p = (await db.select(db.patients).get()).first;
    now = now.add(const Duration(minutes: 1));
    return visits.recordVisit(
      NewVisit(
        patientId: p.id,
        patientName: p.fullName,
        visitType: type,
        scheduledAt: DateTime(2026, 10, 6, 15),
      ),
    );
  }

  /// Records vitals on [visitId], waits for them to sync, and returns the id.
  Future<String> syncedVitals(String visitId, {double temp = 36.8}) async {
    await vitals.save(
      visitId,
      temperatureC: temp,
      systolic: 120,
      diastolic: 80,
    );
    await engine.run();
    return (await db.select(db.vitals).get()).single.id;
  }

  Future<List<Conflict>> unresolved() => conflicts.watchUnresolved().first;

  Future<Visit> seededVisit() async => (await db.select(db.visits).get()).first;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}
