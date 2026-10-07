import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/providers.dart';
import 'change_applier.dart';
import 'conflict_repository.dart';
import 'conflict_resolver.dart';
import 'sync_engine.dart';
import 'sync_providers.dart';
import 'sync_status.dart';

final changeApplierProvider = Provider<ChangeApplier>(
  (ref) => ConflictResolver(
    ref.watch(databaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(entityStoreProvider),
    ref.watch(hlcClockProvider),
  ),
);

/// The one engine. Triggers: reconnect (below), local writes (`nudge`),
/// app foreground and "Sync now" (callers use `run`).
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    api: ref.watch(apiClientProvider),
    applier: ref.watch(changeApplierProvider),
    meta: ref.watch(syncMetaRepositoryProvider),
    deviceId: ref.watch(deviceIdProvider),
    deviceName: () => ref.read(deviceNameProvider),
    isOnline: () => ref.read(isOnlineProvider),
    onProgress: (p) => ref.read(syncProgressProvider.notifier).set(p),
  );
  // Back online → sync (the pill goes Online → Syncing without a tap).
  ref.listen(isOnlineProvider, (prev, online) {
    if (online && prev != true) engine.run();
  });
  ref.onDispose(engine.dispose);
  return engine;
});

final conflictRepositoryProvider = Provider<ConflictRepository>(
  (ref) => ConflictRepository(
    ref.watch(databaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(entityStoreProvider),
    ref.watch(hlcClockProvider),
    nudge: ref.read(syncEngineProvider).nudge,
  ),
);
