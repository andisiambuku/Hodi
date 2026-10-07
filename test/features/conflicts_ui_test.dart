import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/l10n/app_localizations.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/features/visits/presentation/conflicts_section.dart';
import 'package:hodi/features/visits/presentation/visit_detail_screen.dart';

import '../support/overrides.dart';

void main() {
  late AppDatabase db;

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

  Future<void> addConflict(
    ConflictKind kind, {
    String entityType = 'visit',
    String entityId = 'x',
    String field = 'visitType',
    String label = 'visit type',
    String local = '"Malaria test"',
    String remote = '"Home visit"',
    String unit = '',
  }) => db
      .into(db.conflicts)
      .insert(
        ConflictsCompanion.insert(
          id: 'c-${kind.name}',
          entityType: entityType,
          entityId: entityId,
          field: field,
          fieldLabel: label,
          subjectName: 'Peter Otieno',
          localValue: local,
          remoteValue: remote,
          remoteSource: 'Clinic Tablet 2',
          unit: Value(unit),
          kind: kind,
          createdAt: DateTime(2026, 10, 6, 12),
        ),
      );

  Widget host(Widget child) => ProviderScope(
    overrides: testOverrides(db),
    child: MaterialApp(
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('merge banner: dark, worded per spec, dismissible', (
    tester,
  ) async {
    await tester.runAsync(
      () => addConflict(ConflictKind.merged, field: 'scheduledAt'),
    );
    await tester.pumpWidget(host(const ConflictsSection()));
    await settle(tester);

    expect(find.text('Merged a change from Clinic Tablet 2'), findsOneWidget);
    expect(
      find.text("Peter Otieno's visit now has both edits."),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Dismiss'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await settle(tester);
    expect(find.text('Merged a change from Clinic Tablet 2'), findsNothing);
    final left = await tester.runAsync(() => db.select(db.conflicts).get());
    expect(left!.single.resolved, isTrue);
    await shutDown(tester);
  });

  testWidgets('conflict card: spec copy, two buttons, Keep newer confirms', (
    tester,
  ) async {
    await tester.runAsync(
      () => addConflict(
        ConflictKind.replaced,
        entityType: 'vitals',
        field: 'temperatureC',
        label: 'temperature',
        local: '38.4',
        remote: '37.9',
        unit: '°C',
      ),
    );
    await tester.pumpWidget(host(const ConflictsSection()));
    await settle(tester);

    expect(find.text('One of your edits was replaced'), findsOneWidget);
    expect(
      find.text(
        "You changed Peter Otieno's temperature to 38.4 °C. "
        'A newer edit from Clinic Tablet 2 set it to 37.9 °C, '
        'so that value was kept.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Re-enter mine'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Keep newer'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Keep newer'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await settle(tester);
    expect(find.text('Kept the newer value.'), findsOneWidget); // snackbar
    expect(find.text('One of your edits was replaced'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('nothing to show when there are no conflicts', (tester) async {
    await tester.pumpWidget(host(const ConflictsSection()));
    await settle(tester);
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('replaced'), findsNothing);
    await shutDown(tester);
  });

  testWidgets('visit detail: record vitals saves locally and queues them', (
    tester,
  ) async {
    await tester.runAsync(() => seedDemoData(db));
    final visit = (await tester.runAsync(
      () => db.select(db.visits).get(),
    ))!.first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(db),
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: VisitDetailScreen(visitId: visit.id),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('No vitals recorded yet.'), findsOneWidget);

    await tester.tap(find.text('Record vitals'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Temperature (°C)'),
      '38.4',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Systolic (mmHg)'),
      '120',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Diastolic (mmHg)'),
      '80',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Save vitals'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('Temperature: 38.4 °C'), findsOneWidget);
    expect(find.text('Blood pressure: 120/80 mmHg'), findsOneWidget);
    final queued = (await tester.runAsync(() => db.select(db.outbox).get()))!;
    expect(queued.single.entityType, 'vitals');
    expect(queued.single.op, ChangeOp.added);
    expect(queued.single.label, 'Vitals: Amina Wanjiru');
    await shutDown(tester);
  });
}
