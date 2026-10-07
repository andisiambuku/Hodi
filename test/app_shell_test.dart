import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/app/app.dart';
import 'package:hodi/core/db/app_database.dart';

import 'support/overrides.dart';

void main() {
  testWidgets('4-tab shell: lands on Home, tabs switch, state is kept', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(db), child: const HodiApp()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nurse Wairimu'), findsOneWidget);
    expect(find.text('Online'), findsWidgets); // header pill (and the legend)

    for (final tab in ['Patients', 'Sync', 'Profile', 'Visits']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Nurse Wairimu'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
