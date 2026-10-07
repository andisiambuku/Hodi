import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/core/widgets/status_pill.dart';
import 'package:hodi/features/home/presentation/home_screen.dart';
import 'package:hodi/features/profile/presentation/profile_screen.dart';
import 'package:hodi/features/sync/history/presentation/sync_history_screen.dart';
import 'package:hodi/features/sync/hub/presentation/sync_hub_screen.dart';
import 'package:hodi/features/sync/pending_changes/presentation/pending_changes_screen.dart';
import 'package:hodi/features/visits/presentation/visits_screen.dart';
import 'package:hodi/l10n/app_localizations.dart';

import '../support/overrides.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String lang = 'en',
    bool online = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db, online: online),
        child: MaterialApp.router(
          locale: Locale(lang),
          theme: buildAppTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => screen)],
          ),
        ),
      ),
    );
    await settle(tester);
  }

  group('screen reader labels (TalkBack)', () {
    testWidgets('status pill announces itself and is a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const SyncHubScreen());

      final node = tester.getSemantics(find.byType(StatusPill).first);
      expect(node.label, 'Connection status: Online');
      expect(
        node.flagsCollection.isLiveRegion,
        isTrue,
        reason: 'going offline must be announced, not just shown',
      );
      handle.dispose();
      await shutDown(tester);
    });

    testWidgets('the pill reads in Swahili too', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const SyncHubScreen(), lang: 'sw', online: false);
      expect(
        tester.getSemantics(find.byType(StatusPill).first).label,
        'Hali ya muunganisho: Nje ya mtandao',
      );
      handle.dispose();
      await shutDown(tester);
    });

    testWidgets(
      'a visit row is one phrase: who, what, when, and its sync state',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.runAsync(() => seedDemoData(db));
        await tester.runAsync(() async {
          final v = (await db.select(db.visits).get()).first;
          await (db.update(db.visits)..where((t) => t.id.equals(v.id))).write(
            const VisitsCompanion(syncState: Value(SyncState.pending)),
          );
        });
        await pump(tester, const VisitsScreen());

        expect(
          find.bySemanticsLabel(
            'Amina Wanjiru, Antenatal check, 08:15, Waiting',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Joseph Kamau, BP follow-up, 09:02, Synced'),
          findsOneWidget,
        );
        handle.dispose();
        await shutDown(tester);
      },
    );

    testWidgets('the same row in Swahili', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.runAsync(() => seedDemoData(db));
      await pump(tester, const VisitsScreen(), lang: 'sw');
      expect(
        find.bySemanticsLabel(
          'Amina Wanjiru, Uchunguzi wa ujauzito, 08:15, Imesawazishwa',
        ),
        findsOneWidget,
      );
      handle.dispose();
      await shutDown(tester);
    });

    testWidgets(
      'stat tiles, rejected entries and history rows are announced whole',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.runAsync(() async {
          await db
              .into(db.outbox)
              .insert(
                OutboxCompanion.insert(
                  id: 'o1',
                  entityType: 'visit',
                  entityId: 'v',
                  op: ChangeOp.edited,
                  label: 'Visit: Amina Wanjiru',
                  payload: '{"fields":{},"hlc":"x"}',
                  createdAt: DateTime.now(),
                  status: const Value(OutboxStatus.failed),
                ),
              );
          await db
              .into(db.syncLog)
              .insert(
                SyncLogCompanion.insert(
                  id: 'r1',
                  startedAt: DateTime.now(),
                  result: SyncRunResult.failed,
                  summary: 'x',
                ),
              );
        });
        await pump(tester, const PendingChangesScreen());
        expect(
          find.bySemanticsLabel(
            'Edited. Visit: Amina Wanjiru. Rejected by the server',
          ),
          findsOneWidget,
        );

        await pump(tester, const SyncHistoryScreen());
        expect(
          find.bySemanticsLabel('Failed: 1'),
          findsOneWidget,
        ); // its own stop
        expect(find.bySemanticsLabel('Syncs: 1'), findsOneWidget);
        handle.dispose();
        await shutDown(tester);
      },
    );
  });

  group('touch targets are at least 48 x 48 dp', () {
    final screens = <String, Widget Function()>{
      'Home': () => const HomeScreen(),
      'Visits': () => const VisitsScreen(),
      'Pending changes': () => const PendingChangesScreen(),
      'Sync hub': () => const SyncHubScreen(),
      'Profile': () => const ProfileScreen(),
    };
    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        await tester.runAsync(() => seedDemoData(db));
        await pump(tester, entry.value());

        final tooSmall = <String>[];
        void check(Finder f, String what) {
          for (final e in f.evaluate()) {
            final size = tester.getSize(find.byWidget(e.widget));
            if (size.width < 47.9 || size.height < 47.9) {
              tooSmall.add(
                '$what ${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
              );
            }
          }
        }

        check(find.bySubtype<ButtonStyleButton>(), 'button');
        check(find.byType(IconButton), 'icon button');
        check(find.byType(ListTile), 'list tile');
        check(find.byType(SwitchListTile), 'switch tile');
        expect(tooSmall, isEmpty);
        await shutDown(tester);
      });
    }
  });
}
