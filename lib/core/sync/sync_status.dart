import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/fake_api_client.dart';
import '../widgets/status_pill.dart';
import 'connectivity_service.dart';
import 'sync_progress.dart';
import 'sync_providers.dart';

/// Swap for the Dio client once the real API exists.
final apiClientProvider = Provider<ApiClient>((ref) => FakeApiClient());

/// Debug-only: pretend the network is gone.
final simulateOfflineProvider = NotifierProvider<SimulateOfflineNotifier, bool>(
  SimulateOfflineNotifier.new,
);

class SimulateOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = kReleaseMode ? false : value;
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final connectivity = Connectivity();
  final service = ConnectivityService(
    linkChanges: connectivity.onConnectivityChanged,
    currentLink: connectivity.checkConnectivity,
    probe: ref.watch(apiClientProvider).health,
  )..start();
  ref.listen(
    simulateOfflineProvider,
    (_, offline) => service.forceOffline(offline),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Reachable server, debounced. Anything that reacts to "we're back online"
/// (the sync engine, in milestone 5) watches this.
final isOnlineProvider = NotifierProvider<IsOnlineNotifier, bool>(
  IsOnlineNotifier.new,
);

class IsOnlineNotifier extends Notifier<bool> {
  @override
  bool build() {
    final service = ref.watch(connectivityServiceProvider);
    final sub = service.onChanged.listen((v) => state = v);
    ref.onDispose(sub.cancel);
    return service.isOnline;
  }
}

/// Set by the sync engine; null when no sync is running.
final syncProgressProvider =
    NotifierProvider<SyncProgressNotifier, SyncProgress?>(
      SyncProgressNotifier.new,
    );

class SyncProgressNotifier extends Notifier<SyncProgress?> {
  @override
  SyncProgress? build() => null;

  void set(SyncProgress? value) => state = value;
}

/// Changes the engine can still send (queued or in flight). Rejected entries
/// don't count: they need the nurse, not the network.
final sendableCountProvider = StreamProvider<int>(
  (ref) => ref.watch(outboxRepositoryProvider).watchSendableCount(),
);

final lastSyncedAtProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(syncLogRepositoryProvider).watchLastSyncedAt(),
);

/// The header pill (spec §5.1). Offline wins; otherwise unsent work or a
/// running sync means Syncing; otherwise Online.
final syncStatusProvider = Provider<SyncStatusKind>((ref) {
  if (!ref.watch(isOnlineProvider)) return SyncStatusKind.offline;
  final sending =
      ref.watch(syncProgressProvider) != null ||
      (ref.watch(sendableCountProvider).value ?? 0) > 0;
  return sending ? SyncStatusKind.syncing : SyncStatusKind.online;
});
