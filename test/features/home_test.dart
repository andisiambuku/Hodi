import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/core/sync/sync_progress.dart';
import 'package:hodi/core/sync/sync_status.dart';
import 'package:hodi/features/home/domain/home_logic.dart';
import 'package:hodi/features/home/presentation/home_providers.dart';
import 'package:hodi/features/home/presentation/home_screen.dart';
import 'package:hodi/features/sync/hub/presentation/sync_hub_screen.dart';
import 'package:hodi/features/visits/presentation/visit_providers.dart';
import 'package:hodi/features/sync/pending_changes/presentation/pending_changes_screen.dart';
import 'package:intl/intl.dart';

import '../support/overrides.dart';

void main() {
  group('home logic', () {
    test('greeting period by hour: morning, afternoon, evening', () {
      GreetingPeriod at(int h, [int m = 0]) =>
          greetingPeriodFor(DateTime(2026, 10, 6, h, m));
      expect(at(0), GreetingPeriod.morning);
      expect(at(11, 59), GreetingPeriod.morning);
      expect(at(12), GreetingPeriod.afternoon);
      expect(at(16, 59), GreetingPeriod.afternoon);
      expect(at(17), GreetingPeriod.evening);
      expect(at(23, 59), GreetingPeriod.evening);
    });

    test('legend shows for the first 7 days or until hidden', () {
      final first = DateTime(2026, 10, 1);
      bool at(int days, {bool dismissed = false}) => legendVisibleFor(
        firstRun: first,
        dismissed: dismissed,
        now: first.add(Duration(days: days, hours: 1)),
      );
      expect(at(0), isTrue);
      expect(at(6), isTrue);
      expect(at(7), isFalse);
      expect(at(2, dismissed: true), isFalse);
    });
  });

  group('next visit', () {
    late AppDatabase db;
    late List<Visit> visits;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await seedDemoData(db, today: DateTime(2026, 10, 6));
      visits = await (db.select(
        db.visits,
      )..orderBy([(v) => OrderingTerm.asc(v.scheduledAt)])).get();
    });
    tearDown(() => db.close());

    String? nextAt(int h, int m) =>
        nextVisitOf(visits, DateTime(2026, 10, 6, h, m))?.patientName;

    test('is the first visit still ahead of now', () {
      expect(nextAt(7, 0), 'Amina Wanjiru');
      expect(nextAt(8, 15), 'Joseph Kamau'); // 08:15 itself is no longer ahead
      expect(nextAt(9, 30), 'Grace Njeri');
      expect(nextAt(11, 54), 'Daniel Mwangi');
    });

    test('none once the day is over', () {
      expect(nextAt(11, 55), isNull);
      expect(nextAt(18, 0), isNull);
    });

    test('skips completed visits', () {
      final done = [
        for (final v in visits)
          v.patientName == 'Grace Njeri'
              ? v.copyWith(completedAt: Value(DateTime(2026, 10, 6, 9, 41)))
              : v,
      ];
      expect(
        nextVisitOf(done, DateTime(2026, 10, 6, 9, 30))?.patientName,
        'Peter Otieno',
      );
    });
  });

  group('screens', () {
    late AppDatabase db;
    final today = DateTime.now();
    DateTime at(int h, int m) =>
        DateTime(today.year, today.month, today.day, h, m);

    setUp(() => db = AppDatabase(NativeDatabase.memory()));

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
    }

    Future<void> shutDown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    }

    Future<void> pumpApp(
      WidgetTester tester,
      Widget home, {
      bool online = true,
      DateTime? now,
      List<dynamic> extra = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          // ignore: argument_type_not_assignable
          overrides: [
            ...testOverrides(db, online: online),
            clockProvider.overrideWithValue(() => now ?? at(9, 30)),
            ...extra,
          ].cast(),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,

            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => home),
                GoRoute(
                  path: '/sync/pending',
                  builder: (_, _) => const PendingChangesScreen(),
                ),
                GoRoute(
                  path: '/visits/today',
                  builder: (_, _) => const Text('TODAY LIST'),
                ),
                GoRoute(
                  path: '/visits/:id',
                  builder: (_, _) => const Text('VISIT DETAIL'),
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> queue(int n) async {
      for (var i = 0; i < n; i++) {
        await db
            .into(db.outbox)
            .insert(
              OutboxCompanion.insert(
                id: 'o$i',
                entityType: 'visit',
                entityId: 'v$i',
                op: ChangeOp.edited,
                label: 'Visit: Someone $i',
                payload: '{"fields":{},"hlc":"x"}',
                createdAt: at(8, i),
              ),
            );
      }
    }

    testWidgets('greeting, subtitle, hero, and next visit', (tester) async {
      await tester.runAsync(() => seedDemoData(db));
      await pumpApp(tester, const HomeScreen());

      expect(find.text('Good morning, Nurse Wairimu'), findsOneWidget);
      expect(
        find.text('Kinangop, ${DateFormat.EEEE().format(at(9, 30))}'),
        findsOneWidget,
      );
      expect(find.text('6 visits today'), findsOneWidget);
      expect(
        find.textContaining('waiting to sync'),
        findsNothing,
      ); // hidden at 0
      expect(
        find.text('Keep working. Nothing is lost.'),
        findsNothing,
      ); // online
      expect(
        find.text('Grace Njeri'),
        findsOneWidget,
      ); // 09:40 is next at 09:30
      await shutDown(tester);
    });

    testWidgets('before the DB answers, Home claims nothing about the day', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // A stream we control: it stays silent until we say the DB has answered.
      final answer = StreamController<List<Visit>>();
      addTearDown(answer.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(db),
            todaysVisitsProvider.overrideWith((ref) => answer.stream),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Nurse Wairimu'),
        findsOneWidget,
      ); // greeting is fine
      expect(find.text('0 visits today'), findsNothing);
      expect(find.text('No more visits today.'), findsNothing);
      expect(find.text('0 total'), findsNothing);

      answer.add(const []); // answered: an empty day is now the truth
      await tester.pump();
      await tester.pump();
      expect(find.text('0 visits today'), findsOneWidget);
      expect(find.text('No more visits today.'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('afternoon greeting, and no next visit after the last one', (
      tester,
    ) async {
      await tester.runAsync(() => seedDemoData(db));
      await pumpApp(tester, const HomeScreen(), now: at(15, 0));
      expect(find.text('Good afternoon, Nurse Wairimu'), findsOneWidget);
      expect(find.text('No more visits today.'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('offline: reassures; pending line shows the change count', (
      tester,
    ) async {
      await tester.runAsync(() => seedDemoData(db));
      await tester.runAsync(() => queue(3));
      await pumpApp(tester, const HomeScreen(), online: false);

      expect(find.text('Keep working. Nothing is lost.'), findsOneWidget);
      expect(
        find.text('3 changes saved on this phone, waiting to sync'),
        findsOneWidget,
      );
      await shutDown(tester);
    });

    testWidgets('one change reads "1 change", not "1 changes"', (tester) async {
      await tester.runAsync(() => queue(1));
      await pumpApp(tester, const HomeScreen());
      expect(
        find.text('1 change saved on this phone, waiting to sync'),
        findsOneWidget,
      );
      await shutDown(tester);
    });

    testWidgets(
      'the pending number is identical on Home, the Sync hub and Pending changes',
      (tester) async {
        await tester.runAsync(() => queue(5));

        await pumpApp(tester, const HomeScreen());
        expect(
          find.text('5 changes saved on this phone, waiting to sync'),
          findsOneWidget,
        );

        await pumpApp(tester, const SyncHubScreen());
        expect(find.text('Pending changes (5)'), findsOneWidget);

        await pumpApp(tester, const PendingChangesScreen());
        expect(find.text('5 changes waiting to sync'), findsOneWidget);
        await shutDown(tester);
      },
    );

    testWidgets(
      'legend: shown at first, three meanings, static example, can be hidden for good',
      (tester) async {
        await pumpApp(tester, const HomeScreen());

        expect(find.text('What the status pill means'), findsOneWidget);
        expect(
          find.text('All changes are saved to the server'),
          findsOneWidget,
        );
        expect(find.text('Changes are saved on this phone'), findsOneWidget);
        expect(find.text('Sending 3 changes to the server'), findsOneWidget);
        expect(find.text('2 of 3'), findsOneWidget);

        await tester.runAsync(() async {
          await tester.tap(find.text('Hide'));
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await settle(tester);
        expect(find.text('What the status pill means'), findsNothing);
        await shutDown(tester);
      },
    );

    testWidgets('legend stays hidden after 7 days', (tester) async {
      await tester.runAsync(
        () => db
            .into(db.syncMeta)
            .insert(
              SyncMetaCompanion.insert(
                key: 'first_run_at',
                value: at(
                  9,
                  30,
                ).subtract(const Duration(days: 8)).toIso8601String(),
              ),
            ),
      );
      await pumpApp(tester, const HomeScreen());
      expect(find.text('What the status pill means'), findsNothing);
      await shutDown(tester);
    });

    testWidgets('legend progress is live while a sync runs', (tester) async {
      await pumpApp(
        tester,
        const HomeScreen(),
        extra: [syncProgressProvider.overrideWith(_FixedProgress.new)],
      );
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('Sending 4 changes to the server'), findsOneWidget);
      expect(find.text('2 of 3'), findsNothing);
      await shutDown(tester);
    });

    testWidgets(
      'tapping the next visit opens it; the list row opens the list',
      (tester) async {
        await tester.runAsync(() => seedDemoData(db));
        await pumpApp(tester, const HomeScreen());
        await tester.tap(find.text('Grace Njeri'));
        await tester.pumpAndSettle();
        expect(find.text('VISIT DETAIL'), findsOneWidget);
        await shutDown(tester);
      },
    );

    testWidgets(
      'Sync hub: pill meaning, both rows, Sync now; offline explains',
      (tester) async {
        await pumpApp(tester, const SyncHubScreen(), online: false);
        expect(find.text('Changes are saved on this phone'), findsOneWidget);
        expect(find.text('Pending changes (0)'), findsOneWidget);
        expect(find.text('Sync history'), findsOneWidget);
        final b = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(b.onPressed, isNull);
        expect(
          find.text("Sync starts on its own when you're back online."),
          findsOneWidget,
        );
        await shutDown(tester);
      },
    );

    testWidgets('Sync hub: Pending changes row navigates', (tester) async {
      await pumpApp(tester, const SyncHubScreen());
      await tester.tap(find.text('Pending changes (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Everything is synced'), findsOneWidget);
      await shutDown(tester);
    });
  });
}

class _FixedProgress extends SyncProgressNotifier {
  @override
  SyncProgress? build() => const SyncProgress(done: 1, total: 4);
}
