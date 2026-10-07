import 'dart:io';

import 'package:workmanager/workmanager.dart';

import '../db/encrypted_database.dart';
import '../network/api_client.dart';
import '../network/fake_api_client.dart';
import 'conflict_resolver.dart';
import 'entity_schema.dart';
import 'hlc.dart';
import 'outbox_repository.dart';
import 'sync_engine.dart';
import 'sync_meta_repository.dart';

const periodicSyncTask = 'hodi.sync.periodic';
const reconnectSyncTask = 'hodi.sync.reconnect';

/// Background sync needs an [ApiClient] that lives outside the app's memory.
/// The in-memory `FakeApiClient` doesn't, and a background isolate talking to
/// its own empty fake would mark changes "synced" that no server ever saw.
/// Flip to true when the real Dio client replaces the fake.
const backgroundSyncEnabled = false;

ApiClient createBackgroundApiClient() {
  // TODO: return the real Dio client here.
  return FakeApiClient();
}

/// Entry point for the workmanager isolate. It has no Riverpod scope and no
/// UI: it opens the same encrypted DB through the same function as the app.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (!backgroundSyncEnabled) return true;
    final opened = await openEncryptedDatabase();
    try {
      final db = opened.db;
      final meta = SyncMetaRepository(db);
      final deviceId = await meta.deviceId();
      final deviceName = await meta.readDeviceName() ?? 'This phone';
      final engine = SyncEngine(
        db: db,
        api: createBackgroundApiClient(),
        applier: ConflictResolver(
          db,
          OutboxRepository(db),
          EntityStore(db),
          HlcClock(nodeId: deviceId),
        ),
        meta: meta,
        deviceId: deviceId,
        deviceName: () => deviceName,
        isOnline: () => true, // workmanager only fires with a network
      );
      await engine.recoverInterrupted();
      final outcome = await engine.run();
      engine.dispose();
      return !outcome.skipped; // false asks the OS to retry with backoff
    } finally {
      await opened.db.close();
    }
  });
}

/// Android only: a 15-minute periodic sync that needs a network.
Future<void> initBackgroundSync() async {
  if (!backgroundSyncEnabled || !Platform.isAndroid) return;
  await Workmanager().initialize(backgroundCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    periodicSyncTask,
    periodicSyncTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// One-off task that runs as soon as a network is back, even if the app
/// isn't open. Call after a write made while offline.
Future<void> scheduleSyncOnReconnect() async {
  if (!backgroundSyncEnabled || !Platform.isAndroid) return;
  await Workmanager().registerOneOffTask(
    reconnectSyncTask,
    reconnectSyncTask,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
