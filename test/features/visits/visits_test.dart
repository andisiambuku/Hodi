import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/l10n/app_localizations.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/providers.dart';
import '../../support/overrides.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/core/sync/hlc.dart';
import 'package:hodi/core/sync/outbox_repository.dart';
import 'package:hodi/features/visits/data/visit_repository.dart';
import 'package:hodi/features/visits/presentation/visits_screen.dart';

VisitRepository repoFor(AppDatabase db) =>
    VisitRepository(db, OutboxRepository(db), HlcClock(nodeId: 'test'));

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('seed + repository', () {
    test('seeds the six mockup visits in time order', () async {
      await seedDemoData(db, today: DateTime(2026, 10, 6));
      final visits = await repoFor(db).watchDay(DateTime(2026, 10, 6)).first;

      expect(visits.map((v) => v.patientName), [
        'Amina Wanjiru',
        'Joseph Kamau',
        'Grace Njeri',
        'Peter Otieno',
        'Mary Achieng',
        'Daniel Mwangi',
      ]);
      expect(visits.first.visitType, 'Antenatal check');
      expect(visits.first.scheduledAt, DateTime(2026, 10, 6, 8, 15));
    });

    test('seeding twice does not duplicate', () async {
      await seedDemoData(db);
      await seedDemoData(db);
      expect(await db.select(db.visits).get(), hasLength(6));
    });

    test('seeded rows are synced and have no outbox entries', () async {
      await seedDemoData(db);
      final visits = await db.select(db.visits).get();
      expect(visits.every((v) => v.syncState == SyncState.synced), isTrue);
      expect(await db.select(db.outbox).get(), isEmpty);
    });

    test('hides soft-deleted visits and other days; stream re-emits', () async {
      await seedDemoData(db, today: DateTime(2026, 10, 6));
      final repo = repoFor(db);
      final emissions = <int>[];
      final sub = repo
          .watchDay(DateTime(2026, 10, 6))
          .listen((v) => emissions.add(v.length));
      await pumpEventQueue();
      expect(emissions.last, 6);

      final first = (await db.select(db.visits).get()).first;
      await (db.update(db.visits)..where((v) => v.id.equals(first.id))).write(
        const VisitsCompanion(deleted: Value(true)),
      );
      await pumpEventQueue();
      expect(emissions.last, 5);

      expect(await repo.watchDay(DateTime(2026, 10, 7)).first, isEmpty);
      await sub.cancel();
    });

    test('foreign keys are enforced', () async {
      expect(
        () => db
            .into(db.visits)
            .insert(
              VisitsCompanion.insert(
                id: 'v',
                hlc: 'h',
                patientId: 'no-such-patient',
                patientName: 'X',
                visitType: 'T',
                scheduledAt: DateTime.now(),
              ),
            ),
        throwsA(anything),
      );
    });
  });

  group('VisitsScreen', () {
    // Drift streams use real timers; unmount, then close outside FakeAsync.
    Future<void> shutDown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      // Let drift's stream-cancel timers fire on the fake clock first.
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    }

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db),
          child: MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,

            home: const VisitsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders today from the DB with sync badges', (tester) async {
      tester.view.physicalSize = const Size(800, 2400); // all rows built
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => seedDemoData(db));
      await tester.runAsync(() async {
        final v = (await db.select(db.visits).get()).first;
        await (db.update(db.visits)..where((t) => t.id.equals(v.id))).write(
          const VisitsCompanion(syncState: Value(SyncState.pending)),
        );
      });
      await pump(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.text('6 total'), findsOneWidget);
      expect(find.text('Amina Wanjiru'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('◷ Waiting'), findsOneWidget);
      expect(find.text('✓ Synced'), findsNWidgets(5));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await shutDown(tester);
    });

    testWidgets('shows the recovery notice when the key was lost', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db),
          child: Consumer(
            builder: (context, ref, _) {
              return MaterialApp(
                theme: buildAppTheme(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,

                home: const VisitsScreen(),
              );
            },
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VisitsScreen)),
      );
      container.read(dbRecoveredProvider.notifier).set(true);
      await tester.pump();
      expect(
        find.text("This phone's saved data couldn't be opened"),
        findsOneWidget,
      );
      expect(find.textContaining('downloaded again'), findsOneWidget);
      await shutDown(tester);
    });
  });

  group('offline state', () {
    Future<void> pumpOffline(WidgetTester tester, {bool online = false}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(db, online: online),
          child: MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,

            home: const VisitsScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    Future<void> shutDown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    }

    testWidgets('offline: pill says Offline and the banner explains', (
      tester,
    ) async {
      await pumpOffline(tester);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Loaded from this phone'), findsOneWidget);
      expect(find.text('Not synced with the server yet'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('offline banner shows the last successful sync time', (
      tester,
    ) async {
      await tester.runAsync(
        () => db
            .into(db.syncLog)
            .insert(
              SyncLogCompanion.insert(
                id: 'r1',
                startedAt: DateTime(2026, 10, 6, 11, 58),
                finishedAt: Value(DateTime(2026, 10, 6, 11, 58, 4)),
                result: SyncRunResult.done,
                summary: '1 change sent',
              ),
            ),
      );
      await tester.runAsync(
        () => db
            .into(db.syncLog)
            .insert(
              SyncLogCompanion.insert(
                id: 'r2',
                startedAt: DateTime(2026, 10, 6, 12, 30),
                result: SyncRunResult.failed,
                summary: "Server didn't respond. Will retry.",
              ),
            ),
      );
      await pumpOffline(tester);
      // The failed run at 12:30 must not count as "last synced".
      expect(find.text('Last synced with the server at 11:58'), findsOneWidget);
      await shutDown(tester);
    });

    testWidgets('online: no banner, pill says Online', (tester) async {
      await pumpOffline(tester, online: true);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Loaded from this phone'), findsNothing);
      await shutDown(tester);
    });
  });
}
