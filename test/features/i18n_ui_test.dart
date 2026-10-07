import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hodi/app/app.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/features/home/presentation/home_providers.dart';
import 'package:hodi/features/home/presentation/home_screen.dart';
import 'package:hodi/features/sync/history/presentation/sync_history_screen.dart';
import 'package:hodi/features/sync/pending_changes/presentation/pending_changes_screen.dart';
import 'package:hodi/features/visits/presentation/conflicts_section.dart';
import 'package:hodi/features/visits/presentation/visits_screen.dart';
import 'package:hodi/l10n/app_localizations.dart';
import 'package:hodi/core/sync/sync_summary.dart';
import 'package:intl/intl.dart';

import '../support/overrides.dart';

void main() {
  late AppDatabase db;
  final today = DateTime.now();
  DateTime at(int h, int m) =>
      DateTime(today.year, today.month, today.day, h, m);

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

  Future<void> pumpSw(
    WidgetTester tester,
    Widget screen, {
    bool online = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db, online: online),
          clockProvider.overrideWithValue(() => at(9, 30)),
        ],
        child: MaterialApp.router(
          locale: const Locale('sw'),
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

  testWidgets('Home in Swahili', (tester) async {
    await tester.runAsync(() => seedDemoData(db));
    await pumpSw(tester, const HomeScreen());

    expect(find.text('Habari za asubuhi, Nesi Wairimu'), findsOneWidget);
    expect(
      find.text('Kinangop, ${DateFormat.EEEE('sw').format(at(9, 30))}'),
      findsOneWidget,
    );
    expect(find.text('Ziara 6 leo'), findsOneWidget);
    expect(find.text('Maana ya kiashiria cha hali'), findsOneWidget);
    expect(find.text('Mtandaoni'), findsWidgets);
    expect(find.text('Ziara inayofuata'), findsOneWidget);
    expect(find.text('Ziara za leo'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('Visits in Swahili: types, badges and the offline banner', (
    tester,
  ) async {
    await tester.runAsync(() => seedDemoData(db));
    await pumpSw(tester, const VisitsScreen(), online: false);

    expect(find.text('Imepakiwa kutoka kwenye simu hii'), findsOneWidget);
    expect(find.text('Kipimo cha malaria'), findsOneWidget); // Peter's visit
    expect(find.text('✓ Imesawazishwa'), findsWidgets);
    expect(find.text('Nje ya mtandao'), findsOneWidget);
    expect(find.text('Rekodi ziara mpya'), findsOneWidget);
    expect(find.text('Jumla 6'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('Pending changes in Swahili: stored labels are translated', (
    tester,
  ) async {
    await tester.runAsync(
      () => db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              id: 'o1',
              entityType: 'visit',
              entityId: 'v1',
              op: ChangeOp.added,
              label: 'Visit: Grace Njeri', // stored in English on purpose
              payload: '{"fields":{},"hlc":"x"}',
              createdAt: at(8, 0),
            ),
          ),
    );
    await pumpSw(tester, const PendingChangesScreen());

    expect(find.text('Badiliko 1 linasubiri kusawazishwa'), findsOneWidget);
    expect(find.text('Ziara: Grace Njeri'), findsOneWidget);
    expect(find.text('Imeongezwa'), findsOneWidget);
    expect(find.text('Sawazisha sasa'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets(
    'conflict card in Swahili: stored field names and values are translated',
    (tester) async {
      await tester.runAsync(
        () => db
            .into(db.conflicts)
            .insert(
              ConflictsCompanion.insert(
                id: 'c1',
                entityType: 'vitals',
                entityId: 'x',
                field: 'temperatureC',
                fieldLabel: 'temperature', // stored in English
                subjectName: 'Peter Otieno',
                localValue: '38.4',
                remoteValue: '37.9',
                remoteSource: 'Clinic Tablet 2',
                unit: const Value('°C'),
                kind: ConflictKind.replaced,
                createdAt: at(8, 0),
              ),
            ),
      );
      await pumpSw(tester, const Scaffold(body: ConflictsSection()));

      expect(
        find.text('Mojawapo ya mabadiliko yako yalibadilishwa'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Ulibadilisha joto la mwili kwa Peter Otieno kuwa 38.4 °C. '
          'Badiliko jipya zaidi kutoka Clinic Tablet 2 liliiweka kuwa 37.9 °C, '
          'kwa hivyo thamani hiyo ilihifadhiwa.',
        ),
        findsOneWidget,
      );
      expect(find.text('Weka yangu tena'), findsOneWidget);
      expect(find.text('Weka mpya'), findsOneWidget);
      await shutDown(tester);
    },
  );

  testWidgets('sync history summary is translated from stored data', (
    tester,
  ) async {
    // Covered at unit level too; here to prove the screen path uses it.
    await tester.runAsync(
      () => db
          .into(db.syncLog)
          .insert(
            SyncLogCompanion.insert(
              id: 'r1',
              startedAt: at(8, 0),
              result: SyncRunResult.done,
              summary: const SyncSummary(
                SummaryKind.synced,
                sent: 1,
                received: 2,
              ).encode(),
            ),
          ),
    );
    await pumpSw(tester, const SyncHistoryScreen());
    expect(
      find.textContaining('Badiliko 1 limetumwa, 2 yamepokelewa'),
      findsOneWidget,
    );
    expect(find.text('Usawazishaji umekamilika'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets(
    'choosing Kiswahili in Profile switches the whole app and is remembered',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => seedDemoData(db));
      await tester.pumpWidget(
        ProviderScope(overrides: testOverrides(db), child: const HodiApp()),
      );
      await settle(tester);

      expect(find.text('Patients'), findsOneWidget); // English by default

      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phone language'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Kiswahili').last);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('Wagonjwa'), findsOneWidget); // nav tab
      expect(find.text('Wasifu'), findsWidgets);
      expect(find.text('Lugha'), findsOneWidget);
      final saved = await tester.runAsync(() => db.select(db.syncMeta).get());
      expect(saved!.where((m) => m.key == 'locale').single.value, 'sw');
      await shutDown(tester);
    },
  );
}
