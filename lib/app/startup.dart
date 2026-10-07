import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../app/theme/app_theme.dart';
import '../core/db/encrypted_database.dart';
import '../core/db/providers.dart';
import '../core/network/fake_api_client.dart';
import '../core/sync/background_sync.dart';
import '../core/sync/sync_log_repository.dart';
import '../core/sync/sync_meta_repository.dart';
import '../core/sync/sync_providers.dart';
import '../core/sync/sync_status.dart';
import '../l10n/l10n.dart';
import '../l10n/locale_provider.dart';
import 'app.dart';
import 'theme/tokens.dart';

/// Everything the app needs before the first frame.
class StartedApp {
  const StartedApp({
    required this.overrides,
    required this.recoveredFromLostKey,
  });

  final List<Override> overrides;
  final bool recoveredFromLostKey;
}

/// Opens the encrypted DB and loads the saved settings. Throws if the
/// phone's secure storage can't produce the key.
Future<StartedApp> startHodi() async {
  final opened = await openEncryptedDatabase();
  // No real API yet: the in-memory fake server stands in. The app starts
  // empty; patients and visits are whatever the nurse registers.
  final server = FakeApiClient();

  final meta = SyncMetaRepository(opened.db);
  final deviceId = await meta.deviceId();
  final deviceName = await meta.readDeviceName() ?? defaultDeviceName;
  final locale = parseSavedLocale(await meta.readValue(savedLocaleKey));
  await SyncLogRepository(
    opened.db,
  ).pruneOlderThan(DateTime.now().subtract(const Duration(days: 30)));
  await initBackgroundSync();

  return StartedApp(
    recoveredFromLostKey: opened.recoveredFromLostKey,
    overrides: [
      databaseProvider.overrideWithValue(opened.db),
      deviceIdProvider.overrideWithValue(deviceId),
      deviceNameProvider.overrideWith(() => DeviceNameNotifier(deviceName)),
      localeProvider.overrideWith(() => LocaleNotifier(locale)),
      apiClientProvider.overrideWithValue(server),
    ],
  );
}

/// Wipes the DB file and the key together (spec §4a.4). Only ever called
/// after the nurse has confirmed.
Future<void> resetLocalData() => destroyLocalData();

/// Shows the app once it has started, or a way out if it couldn't: never a
/// blank screen. Nothing is deleted automatically, because "can't read the
/// key" also happens briefly after a reboot, before the phone is unlocked.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    this.start = startHodi,
    this.reset = resetLocalData,
  });

  final Future<StartedApp> Function() start;
  final Future<void> Function() reset;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  StartedApp? _started;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _failed = false);
    try {
      final started = await widget.start();
      if (mounted) setState(() => _started = started);
    } catch (e) {
      // Type only: the message could name a file path or a key alias.
      debugPrint('Startup failed: ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _reset() async {
    try {
      await widget.reset();
    } catch (e) {
      debugPrint('Reset failed: ${e.runtimeType}');
    }
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    final started = _started;
    if (started != null) {
      return ProviderScope(
        overrides: started.overrides,
        child: HodiApp(recoveredFromLostKey: started.recoveredFromLostKey),
      );
    }
    if (_failed) {
      return StartupErrorApp(onRetry: _run, onReset: _reset);
    }
    // First frames while the DB opens: the app background, nothing else.
    return const ColoredBox(color: Tokens.background);
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.onRetry,
    required this.onReset,
  });

  final VoidCallback onRetry;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l = context.l10n;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.pagePadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(l.startupErrorTitle, style: Tokens.title),
                    ),
                    const SizedBox(height: Tokens.s12),
                    Text(l.startupErrorBody, style: Tokens.body),
                    const SizedBox(height: Tokens.s24),
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(l.startupRetry),
                    ),
                    const SizedBox(height: Tokens.s8),
                    OutlinedButton(
                      onPressed: () => _confirmReset(context, l),
                      child: Text(l.startupReset),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppLocalizations l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.startupResetTitle),
        content: Text(l.startupResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.startupResetConfirm),
          ),
        ],
      ),
    );
    if (ok == true) onReset();
  }
}
