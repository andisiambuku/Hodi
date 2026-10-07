import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import '../support/overrides.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/features/sync/pending_changes/presentation/pending_changes_screen.dart';
import 'package:hodi/features/visits/domain/new_visit.dart';
import 'package:hodi/features/visits/presentation/record_visit_screen.dart';
import 'package:hodi/features/visits/presentation/visit_providers.dart';
import 'package:hodi/features/visits/presentation/visits_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  // Drift streams use real timers: settle on the real clock, then tear down.
  Future<void> settle(WidgetTester tester) async {
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

  Widget app(Widget home) => ProviderScope(
    overrides: testOverrides(db),
    child: MaterialApp.router(
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home),
          GoRoute(
            path: '/visits/new',
            builder: (_, _) => const RecordVisitScreen(),
          ),
          GoRoute(
            path: '/sync/pending',
            builder: (_, _) => const PendingChangesScreen(),
          ),
        ],
      ),
    ),
  );

  testWidgets('Pending changes: oldest first, count and age banner', (
    tester,
  ) async {
    final t0 = DateTime(2026, 10, 6, 10, 0);
    await tester.runAsync(() async {
      await seedDemoData(db, today: DateTime(2026, 10, 6));
      final container = ProviderContainer(overrides: testOverrides(db));
      final repo = container.read(visitRepositoryProvider);
      final patients = await db.select(db.patients).get();
      await repo.recordVisit(
        NewVisit(
          patientId: patients[0].id,
          patientName: 'Grace Njeri',
          visitType: 'Malaria test',
          scheduledAt: t0,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.recordVisit(
        NewVisit(
          patientId: patients[1].id,
          patientName: 'Peter Otieno',
          visitType: 'Malaria test',
          scheduledAt: t0,
        ),
      );
      container.dispose();
    });

    await tester.pumpWidget(
      app(
        PendingChangesScreen(
          clock: () => DateTime.now().add(const Duration(hours: 2)),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('2 changes waiting to sync'), findsOneWidget);
    expect(find.text('Oldest change made 2 hours ago'), findsOneWidget);
    expect(find.text('Added'), findsNWidgets(2));
    final grace = tester.getTopLeft(find.text('Visit: Grace Njeri')).dy;
    final peter = tester.getTopLeft(find.text('Visit: Peter Otieno')).dy;
    expect(grace, lessThan(peter));
    expect(
      find.text('Changes are kept on the phone, even if it restarts.'),
      findsOneWidget,
    );
    final sync = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(sync.onPressed, isNotNull); // online: Sync now is available
    expect(find.textContaining('Sync starts on its own'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('Pending changes: offline disables Sync now and explains', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db, online: false),
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: const PendingChangesScreen(),
        ),
      ),
    );
    await settle(tester);
    final sync = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(sync.onPressed, isNull);
    expect(
      find.text("Sync starts on its own when you're back online."),
      findsOneWidget,
    );
    await shutDown(tester);
  });

  testWidgets('Pending changes: empty state', (tester) async {
    await tester.pumpWidget(app(const PendingChangesScreen()));
    await settle(tester);
    expect(find.text('Everything is synced'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('Record visit: saves locally, shows Waiting, queues one entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400); // all rows built
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => seedDemoData(db));
    await tester.pumpWidget(app(const VisitsScreen()));
    await settle(tester);
    expect(find.text('✓ Synced'), findsNWidgets(6));

    await tester.tap(find.text('Record new visit'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save visit');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('Patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amina Wanjiru').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visit type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malaria test').last);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(save);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.text('7 total'), findsOneWidget);
    expect(find.text('◷ Waiting'), findsOneWidget);
    final queued = await tester.runAsync(() => db.select(db.outbox).get());
    expect(queued!.single.op, ChangeOp.added);
    await shutDown(tester);
  });
}
