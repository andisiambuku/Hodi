import 'package:drift/drift.dart' show Value;
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
import 'package:hodi/features/home/presentation/home_screen.dart';
import 'package:hodi/features/profile/presentation/profile_screen.dart';
import 'package:hodi/features/sync/history/presentation/sync_history_screen.dart';
import 'package:hodi/features/sync/hub/presentation/sync_hub_screen.dart';
import 'package:hodi/features/sync/pending_changes/presentation/pending_changes_screen.dart';
import 'package:hodi/features/visits/presentation/record_visit_screen.dart';
import 'package:hodi/features/visits/presentation/visit_detail_screen.dart';
import 'package:hodi/features/visits/presentation/visits_screen.dart';

import '../support/overrides.dart';

/// 360 x 640 dp is a common small Android phone.
const _phone = Size(360, 640);

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

  late String firstVisitId;

  Future<void> populate() async {
    await seedDemoData(db);
    final visit = (await db.select(db.visits).get()).first;
    firstVisitId = visit.id;
    await db
        .into(db.vitals)
        .insert(
          VitalsCompanion.insert(
            id: 'vit1',
            hlc: 'h',
            visitId: visit.id,
            temperatureC: const Value(38.4),
            systolic: const Value(120),
            diastolic: const Value(80),
          ),
        );
    for (final (i, op) in ChangeOp.values.indexed) {
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              id: 'o$i',
              entityType: 'visit',
              entityId: visit.id,
              op: op,
              label: 'Visit: Amina Wanjiru',
              payload: '{"fields":{},"hlc":"x"}',
              createdAt: DateTime.now().subtract(Duration(minutes: 10 - i)),
              status: Value(i == 2 ? OutboxStatus.failed : OutboxStatus.queued),
            ),
          );
    }
    for (final (i, r) in SyncRunResult.values.indexed) {
      await db
          .into(db.syncLog)
          .insert(
            SyncLogCompanion.insert(
              id: 'r$i',
              startedAt: DateTime.now().subtract(Duration(hours: i + 1)),
              result: r,
              summary:
                  "Server didn't respond. Will retry. It can be a long sentence.",
            ),
          );
    }
    for (final k in ConflictKind.values) {
      await db
          .into(db.conflicts)
          .insert(
            ConflictsCompanion.insert(
              id: 'c-${k.name}',
              entityType: 'vitals',
              entityId: 'vit1',
              field: 'temperatureC',
              fieldLabel: 'temperature',
              subjectName: 'Peter Otieno',
              localValue: '38.4',
              remoteValue: '37.9',
              remoteSource: 'Clinic Tablet 2',
              unit: const Value('°C'),
              kind: k,
              createdAt: DateTime.now(),
            ),
          );
    }
  }

  Future<void> pumpAtScale(
    WidgetTester tester,
    Widget screen, {
    double scale = 2.0,
    bool online = true,
    bool seed = true,
    Locale? locale,
  }) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (seed) await tester.runAsync(populate);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db, online: online),
        child: MaterialApp.router(
          locale: locale,
          theme: buildAppTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => screen)],
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Scrolls to the end so lazily built children are laid out too.
  Future<void> scrollThrough(WidgetTester tester) async {
    final list = find.byType(Scrollable);
    if (list.evaluate().isEmpty) return;
    for (var i = 0; i < 6; i++) {
      await tester.drag(list.first, const Offset(0, -300));
      await tester.pump();
    }
  }

  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Visits': () => const VisitsScreen(),
    'Pending changes': () => const PendingChangesScreen(),
    'Sync history': () => const SyncHistoryScreen(),
    'Sync hub': () => const SyncHubScreen(),
    'Profile': () => const ProfileScreen(),
    'Record visit': () => const RecordVisitScreen(),
  };

  group('200% text scale: no overflow, everything reachable', () {
    for (final lang in const ['en', 'sw']) {
      for (final entry in screens.entries) {
        for (final online in [true, false]) {
          testWidgets(
            '${entry.key} ($lang, ${online ? 'online' : 'offline'})',
            (tester) async {
              await pumpAtScale(
                tester,
                entry.value(),
                online: online,
                locale: Locale(lang),
              );
              await scrollThrough(tester);
              expect(tester.takeException(), isNull);
              await shutDown(tester);
            },
          );
        }
      }
    }

    testWidgets('Visit detail (with vitals)', (tester) async {
      // pumpAtScale populates first; build the screen once the id is known.
      await tester.runAsync(populate);
      await pumpAtScale(
        tester,
        VisitDetailScreen(visitId: firstVisitId),
        seed: false,
      );
      expect(find.textContaining('Temperature'), findsOneWidget);
      await scrollThrough(tester);
      expect(tester.takeException(), isNull);
      await shutDown(tester);
    });
  });

  testWidgets('sanity: the overflow check really detects an overflow', (
    tester,
  ) async {
    // A deliberately bad layout, so a pass above can't be a silent no-op.
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: Row(
              children: [Text('A label that is much too long to fit in a row')],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNotNull);
    await shutDown(tester);
  });
}
