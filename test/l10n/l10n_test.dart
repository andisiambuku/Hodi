import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/sync/sync_summary.dart';
import 'package:hodi/l10n/l10n.dart';

import '../support/l10n.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Names of `{placeholders}` in an ICU message, ignoring plural/select syntax.
Set<String> _placeholders(String message) {
  // `{name}` on its own, or `{name, plural, ...}` / `{name, select, ...}`.
  // Plural branch text such as `{1 change}` is not a placeholder.
  final simple = RegExp(r'\{(\w+)\}');
  final typed = RegExp(r'\{(\w+),\s*(?:plural|select)\b');
  return {
    for (final m in simple.allMatches(message)) m.group(1)!,
    for (final m in typed.allMatches(message)) m.group(1)!,
  };
}

void main() {
  final enArb = _arb('en');
  final swArb = _arb('sw');
  final keys = enArb.keys.where((k) => !k.startsWith('@')).toList();

  group('ARB files', () {
    test('Swahili has every English key and nothing extra', () {
      final sw = swArb.keys.where((k) => !k.startsWith('@')).toSet();
      expect(keys.toSet().difference(sw), isEmpty, reason: 'untranslated keys');
      expect(
        sw.difference(keys.toSet()),
        isEmpty,
        reason: 'keys not in English',
      );
    });

    test('every key uses the same placeholders in both languages', () {
      for (final k in keys) {
        expect(
          _placeholders(swArb[k] as String),
          _placeholders(enArb[k] as String),
          reason: 'placeholders differ for "$k"',
        );
      }
    });

    test('no translation is empty, or identical to English by accident', () {
      const sameOnPurpose = {
        'appTitle',
        'langEnglish',
        'langSwahili',
        'conflictMergedBody',
        'statSemantics',
        'visitCardSemantics',
        'runSemantics',
        'entrySemantics',
        'homeSubtitle',
        'runTimeWeekday',
        'runTimeDate',
        'progressOf',
      };
      for (final k in keys) {
        final sw = (swArb[k] as String).trim();
        expect(sw, isNotEmpty, reason: '"$k" is empty');
        if (!sameOnPurpose.contains(k)) {
          expect(sw, isNot(enArb[k]), reason: '"$k" looks untranslated');
        }
      }
    });
  });

  group('plurals', () {
    test('English and Swahili agree on 0, 1 and many', () {
      expect(en.homeVisitsToday(1), '1 visit today');
      expect(en.homeVisitsToday(6), '6 visits today');
      expect(sw.homeVisitsToday(1), 'Ziara 1 leo');
      expect(sw.homeVisitsToday(6), 'Ziara 6 leo');
      expect(en.pendingBannerTitle(1), '1 change waiting to sync');
      expect(sw.pendingBannerTitle(1), 'Badiliko 1 linasubiri kusawazishwa');
      expect(sw.pendingBannerTitle(5), 'Mabadiliko 5 yanasubiri kusawazishwa');
      expect(sw.relMinutes(1), 'dakika 1 iliyopita');
      expect(sw.relMinutes(7), 'dakika 7 zilizopita');
    });
  });

  group('stored data is translated when shown', () {
    test('sync summaries', () {
      final stored = const SyncSummary(
        SummaryKind.synced,
        sent: 6,
        received: 4,
        merged: 1,
      ).encode();
      expect(
        localizedSummary(en, stored),
        '6 changes sent, 4 received, 1 merged',
      );
      expect(
        localizedSummary(sw, stored),
        'Mabadiliko 6 yametumwa, 4 yamepokelewa, 1 yameunganishwa',
      );
      expect(
        localizedSummary(sw, const SyncSummary(SummaryKind.server).encode()),
        'Seva haikujibu. Itajaribu tena.',
      );
    });

    test('text that is not ours is shown unchanged', () {
      expect(
        localizedSummary(sw, 'Something from before'),
        'Something from before',
      );
    });

    test('visit types: known ones translate, unknown pass through', () {
      expect(localizedVisitType(sw, 'Malaria test'), 'Kipimo cha malaria');
      expect(localizedVisitType(sw, 'Custom visit'), 'Custom visit');
    });

    test('outbox labels keep the name and translate the prefix', () {
      expect(
        localizedEntityLabel(sw, 'visit', 'Visit: Grace Njeri'),
        'Ziara: Grace Njeri',
      );
      expect(
        localizedEntityLabel(sw, 'vitals', 'Vitals: Peter Otieno'),
        'Viashiria: Peter Otieno',
      );
      expect(
        localizedEntityLabel(sw, 'visit', 'No prefix'),
        'Ziara: No prefix',
      );
    });
  });

  group('no hard-coded English in widgets', () {
    // A guard, not a proof: user-facing literals belong in the ARB files.
    test('presentation code passes only localized text to Text/title/label', () {
      final literal = RegExp(
        r'''(Text\(|title:|message:|label:|subtitle:|tooltip:|labelText:|helperText:|hintText:)\s*(const\s+)?['"][A-Za-z]''',
      );
      final offenders = <String>[];
      final roots = [
        Directory('lib/features'),
        Directory('lib/core/widgets'),
        Directory('lib/app'),
      ];
      for (final root in roots) {
        for (final f in root.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          // Data-layer files store canonical English values on purpose.
          if (f.path.contains('/data/') || f.path.contains('domain/')) continue;
          // Debug-only tooling is hidden in release builds.
          if (f.path.contains('debug_remote_edits')) continue;
          final lines = f.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.trimLeft().startsWith('//')) continue;
            if (line.contains('Simulate') || line.contains("'Debug'")) continue;
            if (literal.hasMatch(line)) {
              offenders.add('${f.path}:${i + 1}: ${line.trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'hard-coded UI text:\n${offenders.join('\n')}',
      );
    });
  });
}
