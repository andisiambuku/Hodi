import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/widgets/list_card.dart';
import 'package:hodi/features/sync/pending_changes/presentation/pending_changes_screen.dart';
import 'package:hodi/l10n/app_localizations.dart';

import '../support/overrides.dart';

void main() {
  testWidgets(
    '500 pending changes: only the visible rows are built, and the list scrolls to the end',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() async {
        await db.batch((b) {
          b.insertAll(db.outbox, [
            for (var i = 0; i < 500; i++)
              OutboxCompanion.insert(
                id: 'o${i.toString().padLeft(3, '0')}',
                entityType: 'visit',
                entityId: 'v$i',
                op: ChangeOp.edited,
                label: 'Visit: Patient $i',
                payload: '{"fields":{},"hlc":"x"}',
                createdAt: DateTime(2026, 10, 6, 8).add(Duration(seconds: i)),
              ),
          ]);
        });
      });

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db),
          child: MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PendingChangesScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();

      expect(find.text('500 changes waiting to sync'), findsOneWidget);
      final built = find.byType(ListCard).evaluate().length;
      expect(built, lessThan(30), reason: 'built $built of 500 rows eagerly');
      expect(
        find.text('Patient 0'),
        findsNothing,
      ); // label is "Visit: Patient 0"
      expect(find.text('Visit: Patient 0'), findsOneWidget); // oldest first

      // Scroll all the way down: the footnote and Sync now are reachable.
      await tester.fling(
        find.byType(Scrollable),
        const Offset(0, -50000),
        20000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Visit: Patient 499'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    },
  );
}
