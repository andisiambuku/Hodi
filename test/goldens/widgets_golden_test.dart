import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/l10n/app_localizations.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/app/theme/tokens.dart';
import 'package:hodi/core/widgets/avatar_initial.dart';
import 'package:hodi/core/widgets/banner_card.dart';
import 'package:hodi/core/widgets/list_card.dart';
import 'package:hodi/core/widgets/stat_tile.dart';
import 'package:hodi/core/widgets/status_pill.dart';
import 'package:hodi/core/widgets/sync_badge.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(Tokens.s16),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('status pill: three states', (tester) async {
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Tokens.s8,
        children: [for (final k in SyncStatusKind.values) StatusPill(kind: k)],
      ),
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('status_pill.png'),
    );
  });

  testWidgets('sync badge: all kinds', (tester) async {
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Tokens.s8,
        children: [for (final k in SyncBadgeKind.values) SyncBadge(kind: k)],
      ),
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('sync_badge.png'),
    );
  });

  testWidgets('banner card: variants', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 368,
        child: Column(
          spacing: Tokens.s8,
          children: [
            const BannerCard(
              variant: BannerVariant.success,
              title: 'Loaded from this phone',
              message: 'Last synced with the server at 08:02',
            ),
            const BannerCard(
              variant: BannerVariant.warning,
              title: '5 changes waiting to sync',
              message: 'Oldest change made 12 minutes ago',
            ),
            const BannerCard(
              variant: BannerVariant.info,
              title: 'Sending 3 changes',
            ),
            const BannerCard(
              variant: BannerVariant.error,
              title: 'One of your edits was replaced',
              message: 'A newer edit set it to 37.9 °C.',
            ),
            BannerCard(
              variant: BannerVariant.dark,
              title: 'Merged a change from your tablet',
              message: "Amina Wanjiru's visit now has both edits.",
              onDismiss: () {},
            ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('banner_card.png'),
    );
  });

  testWidgets('stat tile', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 160,
        child: StatTile(label: 'Failed', value: 2, valueColor: Tokens.danger),
      ),
    );
    await expectLater(
      find.byType(StatTile),
      matchesGoldenFile('stat_tile.png'),
    );
  });

  testWidgets('list card with avatar and badge', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 368,
        child: ListCard(
          leading: AvatarInitial(name: 'Amina Wanjiru'),
          title: 'Amina Wanjiru',
          subtitle: 'Antenatal check · 08:15',
          trailing: SyncBadge(kind: SyncBadgeKind.waiting),
        ),
      ),
    );
    await expectLater(
      find.byType(ListCard),
      matchesGoldenFile('list_card.png'),
    );
  });
}
