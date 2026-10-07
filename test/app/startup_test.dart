import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/app/startup.dart';
import 'package:hodi/core/db/app_database.dart';

import '../support/overrides.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> shutDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  }

  StartedApp ok() =>
      StartedApp(overrides: testOverrides(db), recoveredFromLostKey: false);

  testWidgets('a failing start shows a way out, never a blank screen', (
    tester,
  ) async {
    var starts = 0;
    var resets = 0;
    await tester.pumpWidget(
      StartupGate(
        start: () async {
          starts++;
          throw StateError('keystore says no');
        },
        reset: () async => resets++,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("This phone's secure storage couldn't be opened"),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text("Reset this phone's data"), findsOneWidget);
    expect(
      find.textContaining('keystore'),
      findsNothing,
      reason: 'no internals shown',
    );
    expect(starts, 1);
    expect(resets, 0, reason: 'nothing is wiped automatically');
  });

  testWidgets('Try again starts again and, once it works, shows the app', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      StartupGate(
        start: () async {
          starts++;
          if (starts == 1) throw StateError('locked');
          return ok();
        },
        reset: () async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(starts, 2);
    expect(find.textContaining('Nurse Wairimu'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('reset asks first; Cancel changes nothing', (tester) async {
    var resets = 0;
    await tester.pumpWidget(
      StartupGate(
        start: () async => throw StateError('x'),
        reset: () async => resets++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Reset this phone's data"));
    await tester.pumpAndSettle();
    expect(find.text("Reset this phone's data?"), findsOneWidget);
    expect(
      find.textContaining("won't be sent").evaluate().length +
          find.textContaining("haven't been sent").evaluate().length,
      1,
      reason: 'the dialog says what will be lost',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(resets, 0);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('confirming the reset wipes, then starts fresh', (tester) async {
    var starts = 0;
    var resets = 0;
    await tester.pumpWidget(
      StartupGate(
        start: () async {
          starts++;
          if (resets == 0) throw StateError('x');
          return ok();
        },
        reset: () async => resets++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Reset this phone's data"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(resets, 1);
    expect(starts, 2);
    expect(find.textContaining('Nurse Wairimu'), findsOneWidget);
    await shutDown(tester);
  });

  testWidgets('a reset that itself fails still returns to the error screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupGate(
        start: () async => throw StateError('x'),
        reset: () async => throw StateError('cannot delete'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Reset this phone's data"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
  });
}
