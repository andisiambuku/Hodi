import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/providers.dart';
import 'entity_schema.dart';
import 'hlc.dart';
import 'outbox_repository.dart';
import 'sync_log_repository.dart';
import 'sync_meta_repository.dart';

/// Stable per install. Overridden in `main()` after reading it from the DB.
final deviceIdProvider = Provider<String>(
  (ref) => throw StateError('deviceIdProvider must be overridden at startup'),
);

const defaultDeviceName = 'This phone';

/// The name other devices see in conflict copy, e.g. "Clinic Tablet 2".
final deviceNameProvider = NotifierProvider<DeviceNameNotifier, String>(
  DeviceNameNotifier.new,
);

class DeviceNameNotifier extends Notifier<String> {
  DeviceNameNotifier([this._initial = defaultDeviceName]);

  final String _initial;

  @override
  String build() => _initial;

  Future<void> rename(String name) async {
    final clean = name.trim().isEmpty ? defaultDeviceName : name.trim();
    state = clean;
    await ref.read(syncMetaRepositoryProvider).writeDeviceName(clean);
  }
}

final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(ref.watch(databaseProvider)),
);

final syncLogRepositoryProvider = Provider<SyncLogRepository>(
  (ref) => SyncLogRepository(ref.watch(databaseProvider)),
);

final syncMetaRepositoryProvider = Provider<SyncMetaRepository>(
  (ref) => SyncMetaRepository(ref.watch(databaseProvider)),
);

final entityStoreProvider = Provider<EntityStore>(
  (ref) => EntityStore(ref.watch(databaseProvider)),
);

/// One clock per app run, node id = device id.
// TODO(milestone 8): seed from the latest stored HLC.
final hlcClockProvider = Provider<HlcClock>(
  (ref) => HlcClock(nodeId: ref.watch(deviceIdProvider)),
);
