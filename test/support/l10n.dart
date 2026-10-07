import 'dart:ui';

import 'package:hodi/core/sync/sync_summary.dart';
import 'package:hodi/l10n/app_localizations.dart';

/// Localizations without a widget tree, for unit tests.
final en = lookupAppLocalizations(const Locale('en'));
final sw = lookupAppLocalizations(const Locale('sw'));

/// A sync_log row's summary in English (the column stores structured data).
String summaryText(String stored) =>
    SyncSummary.parse(stored)?.english ?? stored;
