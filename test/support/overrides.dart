import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/providers.dart';
import 'package:hodi/core/network/fake_api_client.dart';
import 'package:hodi/core/sync/sync_engine.dart';
import 'package:hodi/core/sync/sync_engine_provider.dart';
import 'package:hodi/core/sync/sync_providers.dart';
import 'package:hodi/core/sync/sync_status.dart';

/// Test wiring: in-memory DB, a fixed connectivity answer (no platform
/// channels), a zero-latency fake server, and by default an inert sync
/// engine so debounce timers can't fire inside FakeAsync. Pass
/// [realEngine] to exercise real syncing in a widget test.
List<Override> testOverrides(
  AppDatabase db, {
  bool online = true,
  bool realEngine = false,
  FakeApiClient? api,
  SyncEngine? engine,
}) => [
  databaseProvider.overrideWithValue(db),
  deviceIdProvider.overrideWithValue('test-device'),
  apiClientProvider.overrideWithValue(
    api ?? FakeApiClient(latency: Duration.zero),
  ),
  isOnlineProvider.overrideWith(() => _FixedOnline(online)),
  if (engine != null)
    syncEngineProvider.overrideWithValue(engine)
  else if (!realEngine)
    syncEngineProvider.overrideWith(_inertEngine),
];

/// Never online, so `nudge()` and `run()` do nothing.
SyncEngine _inertEngine(Ref ref) => SyncEngine(
  db: ref.watch(databaseProvider),
  api: ref.watch(apiClientProvider),
  applier: ref.watch(changeApplierProvider),
  meta: ref.watch(syncMetaRepositoryProvider),
  deviceId: 'test-device',
  isOnline: () => false,
);

class _FixedOnline extends IsOnlineNotifier {
  _FixedOnline(this._value);

  final bool _value;

  @override
  bool build() => _value;
}
