import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/sync_providers.dart';

const supportedLanguageCodes = ['en', 'sw'];
const _localeKey = 'locale';

/// The language the nurse picked; null follows the phone's language.
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale?> {
  LocaleNotifier([this._initial]);

  final Locale? _initial;

  @override
  Locale? build() => _initial;

  Future<void> choose(String? languageCode) async {
    state = languageCode == null ? null : Locale(languageCode);
    await ref
        .read(syncMetaRepositoryProvider)
        .writeValue(_localeKey, languageCode ?? '');
  }
}

/// Reads the saved choice at startup (before `runApp`).
Locale? parseSavedLocale(String? saved) =>
    saved != null && supportedLanguageCodes.contains(saved)
    ? Locale(saved)
    : null;

const savedLocaleKey = _localeKey;
