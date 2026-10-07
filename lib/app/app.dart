import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/providers.dart';
import '../core/sync/sync_engine_provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class HodiApp extends ConsumerStatefulWidget {
  const HodiApp({super.key, this.recoveredFromLostKey = false});

  final bool recoveredFromLostKey;

  @override
  ConsumerState<HodiApp> createState() => _HodiAppState();
}

class _HodiAppState extends ConsumerState<HodiApp> with WidgetsBindingObserver {
  final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final engine = ref.read(syncEngineProvider);
    // Anything a killed app left in flight goes back to the queue first.
    engine.recoverInterrupted().then((_) => engine.run());
    if (widget.recoveredFromLostKey) {
      // Provider writes can't happen during build; defer to after first frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(dbRecoveredProvider.notifier).set(true),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncEngineProvider).run();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
