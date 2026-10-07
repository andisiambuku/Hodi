import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/network/fake_api_client.dart';
import 'package:hodi/core/sync/conflict_resolver.dart';
import 'package:hodi/core/sync/entity_schema.dart';
import 'package:hodi/core/sync/hlc.dart';
import 'package:hodi/core/sync/outbox_repository.dart';
import 'package:hodi/core/sync/sync_engine.dart';
import 'package:hodi/core/sync/sync_meta_repository.dart';
import 'package:hodi/core/sync/sync_progress.dart';
import 'package:hodi/core/sync/sync_status.dart';
import 'package:hodi/core/widgets/stat_tile.dart';
import 'package:hodi/features/sync/history/presentation/sync_history_screen.dart';
import 'package:hodi/l10n/l10n.dart';
import 'package:hodi/features/sync/pending_changes/presentation/pending_changes_screen.dart';

import '../support/l10n.dart';
import '../support/overrides.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

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

  Widget app(Widget home, List<dynamic> overrides) => ProviderScope(
    // ignore: argument_type_not_assignable
    overrides: overrides.cast(),
    child: MaterialApp.router(
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => home)],
      ),
    ),
  );

  Future<void> addRun(
    String id,
    DateTime at,
    SyncRunResult r,
    String summary,
  ) => db
      .into(db.syncLog)
      .insert(
        SyncLogCompanion.insert(
          id: id,
          startedAt: at,
          finishedAt: Value(at),
          result: r,
          summary: summary,
        ),
      );

  group('Sync history', () {
    testWidgets('stat tiles count the log; recent syncs are newest first', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 6, 12);
      await tester.runAsync(() async {
        // Inserted out of order on purpose.
        await addRun(
          'a',
          DateTime(2026, 10, 5, 17, 20),
          SyncRunResult.done,
          '2 changes sent, 0 received',
        );
        await addRun(
          'c',
          DateTime(2026, 10, 6, 11, 58),
          SyncRunResult.done,
          '6 changes sent, 4 received',
        );
        await addRun(
          'b',
          DateTime(2026, 10, 5, 17, 31),
          SyncRunResult.failed,
          "Server didn't respond. Will retry.",
        );
        await addRun(
          'd',
          DateTime(2026, 10, 1, 9, 5),
          SyncRunResult.merged,
          '1 change sent, 1 received',
        );
      });
      await tester.pumpWidget(
        app(SyncHistoryScreen(clock: () => now), testOverrides(db)),
      );
      await settle(tester);

      final tiles = tester
          .widgetList<StatTile>(find.byType(StatTile))
          .map((t) => (t.label, t.value))
          .toList();
      expect(tiles, [('Syncs', 4), ('Done', 2), ('Merged', 1), ('Failed', 1)]);

      final newest = tester.getTopLeft(find.textContaining('Today 11:58')).dy;
      final mid = tester.getTopLeft(find.textContaining('Yesterday 17:31')).dy;
      final older = tester
          .getTopLeft(find.textContaining('Yesterday 17:20'))
          .dy;
      expect(newest, lessThan(mid));
      expect(mid, lessThan(older));
      expect(find.text('Sync complete'), findsNWidgets(2));
      expect(find.text('Sync failed'), findsOneWidget);
      expect(find.text('Sync with a merge'), findsOneWidget);
      expect(
        find.textContaining("Server didn't respond. Will retry."),
        findsOneWidget,
      );
      await shutDown(tester);
    });

    testWidgets('empty history', (tester) async {
      await tester.pumpWidget(
        app(const SyncHistoryScreen(), testOverrides(db)),
      );
      await settle(tester);
      expect(find.text('No syncs yet.'), findsOneWidget);
      await shutDown(tester);
    });

    test(
      'timestamps: Today / Yesterday / weekday / date, in both languages',
      () {
        final now = DateTime(2026, 10, 6, 12); // a Tuesday
        String f(DateTime t, [bool swahili = false]) =>
            formatRunTimeL(swahili ? sw : en, swahili ? 'sw' : 'en', t, now);
        expect(f(DateTime(2026, 10, 6, 11, 58)), 'Today 11:58');
        expect(f(DateTime(2026, 10, 5, 9, 10)), 'Yesterday 09:10');
        expect(f(DateTime(2026, 10, 2, 17, 20)), 'Fri 17:20');
        expect(f(DateTime(2026, 9, 12, 8, 0)), '12 Sep 08:00');
        expect(f(DateTime(2026, 10, 6, 11, 58), true), 'Leo 11:58');
        expect(f(DateTime(2026, 10, 5, 9, 10), true), 'Jana 09:10');
      },
    );
  });

  group('Sync now button', () {
    testWidgets('triggers a manual run on the engine', (tester) async {
      final spy = _SpyEngine(db);
      await tester.pumpWidget(
        app(const PendingChangesScreen(), testOverrides(db, engine: spy)),
      );
      await settle(tester);

      await tester.tap(find.text('Sync now'));
      await tester.pump();
      expect(spy.triggers, [SyncTrigger.manual]);
      await shutDown(tester);
    });

    testWidgets('shows x of N and is disabled while a sync is running', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const PendingChangesScreen(), [
          ...testOverrides(db),
          syncProgressProvider.overrideWith(_FixedProgress.new),
        ]),
      );
      await settle(tester);

      expect(find.text('Sending 1 of 3 changes'), findsOneWidget);
      final b = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(b.onPressed, isNull);
      await shutDown(tester);
    });
  });
}

class _SpyEngine extends SyncEngine {
  _SpyEngine(AppDatabase db)
    : super(
        db: db,
        api: FakeApiClient(latency: Duration.zero),
        applier: ConflictResolver(
          db,
          OutboxRepository(db),
          EntityStore(db),
          HlcClock(nodeId: 'spy'),
        ),
        meta: SyncMetaRepository(db),
        deviceId: 'spy',
        isOnline: () => true,
      );

  final triggers = <SyncTrigger>[];

  @override
  Future<SyncOutcome> run({SyncTrigger trigger = SyncTrigger.auto}) {
    triggers.add(trigger);
    return Future.value(const SyncOutcome.skipped());
  }
}

class _FixedProgress extends SyncProgressNotifier {
  @override
  SyncProgress? build() => const SyncProgress(done: 1, total: 3);
}
