import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hodi/app/theme/app_theme.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/sync/hlc.dart';
import 'package:hodi/core/sync/outbox_repository.dart';
import 'package:hodi/features/patients/data/patient_repository.dart';
import 'package:hodi/features/patients/domain/new_patient.dart';
import 'package:hodi/features/patients/presentation/patients_screen.dart';
import 'package:hodi/features/patients/presentation/register_patient_screen.dart';
import 'package:hodi/l10n/app_localizations.dart';

import '../../support/overrides.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  group('PatientRepository.register', () {
    late OutboxRepository outbox;
    late PatientRepository repo;
    var nudges = 0;

    setUp(() {
      outbox = OutboxRepository(db);
      nudges = 0;
      repo = PatientRepository(
        db,
        outbox,
        HlcClock(nodeId: 't', now: () => DateTime(2026, 10, 7, 9)),
        nudge: () => nudges++,
        now: () => DateTime(2026, 10, 7, 9),
      );
    });
    tearDown(() => db.close());

    test(
      'saves household and patient with two pending outbox entries',
      () async {
        final id = await repo.register(
          NewPatient(
            fullName: ' Amina Wanjiru ',
            headName: 'Joseph Kamau',
            location: 'Kinangop',
          ),
        );

        final patient = await (db.select(
          db.patients,
        )..where((p) => p.id.equals(id))).getSingle();
        expect(patient.fullName, 'Amina Wanjiru');
        expect(patient.syncState, SyncState.pending);

        final household = await (db.select(
          db.households,
        )..where((h) => h.id.equals(patient.householdId!))).getSingle();
        expect(household.headName, 'Joseph Kamau');
        expect(household.location, 'Kinangop');

        final entries = await outbox.watchPending().first;
        expect(entries.map((e) => e.entityType), ['household', 'patient']);
        expect(entries.every((e) => e.op == ChangeOp.added), isTrue);
        expect(nudges, 1);
      },
    );

    test('head of household defaults to the patient', () async {
      final id = await repo.register(
        NewPatient(fullName: 'Grace Njeri', headName: '  ', location: 'Nyeri'),
      );
      final patient = await (db.select(
        db.patients,
      )..where((p) => p.id.equals(id))).getSingle();
      final household = await (db.select(
        db.households,
      )..where((h) => h.id.equals(patient.householdId!))).getSingle();
      expect(household.headName, 'Grace Njeri');
    });

    test('rejects a missing name or location and writes nothing', () async {
      await expectLater(
        repo.register(NewPatient(fullName: '', location: 'Nyeri')),
        throwsArgumentError,
      );
      await expectLater(
        repo.register(NewPatient(fullName: 'Grace', location: ' ')),
        throwsArgumentError,
      );
      expect(await db.select(db.patients).get(), isEmpty);
      expect(await db.select(db.households).get(), isEmpty);
      expect(await outbox.watchPending().first, isEmpty);
      expect(nudges, 0);
    });
  });

  group('screens', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    Widget app() => ProviderScope(
      overrides: testOverrides(db),
      child: MaterialApp.router(
        theme: buildAppTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const PatientsScreen(),
              routes: [
                GoRoute(
                  path: 'patients/new',
                  builder: (_, _) => const RegisterPatientScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    Future<void> shutDown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    }

    testWidgets('empty state, then register a patient end to end', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.textContaining('No patients yet'), findsOneWidget);

      await tester.tap(find.text('Register patient'));
      await tester.pumpAndSettle();

      FilledButton saveButton() =>
          tester.widget(find.widgetWithText(FilledButton, 'Save patient'));
      expect(saveButton().onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Full name'),
        'Amina Wanjiru',
      );
      await tester.pump();
      expect(saveButton().onPressed, isNull, reason: 'location is required');

      await tester.enterText(
        find.widgetWithText(TextField, 'Location'),
        'Kinangop',
      );
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Save patient'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Amina Wanjiru'), findsOneWidget);
      expect(find.textContaining('No patients yet'), findsNothing);
      await shutDown(tester);
    });
  });
}
