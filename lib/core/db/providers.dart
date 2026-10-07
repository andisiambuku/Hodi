import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Overridden in `main()` with the opened, encrypted database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('databaseProvider must be overridden at startup'),
);

/// True once, when the DB key was lost and local data was reset. The Visits
/// screen explains this to the user.
final dbRecoveredProvider = NotifierProvider<DbRecoveredNotifier, bool>(
  DbRecoveredNotifier.new,
);

class DbRecoveredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
  void dismiss() => state = false;
}
