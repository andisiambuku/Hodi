import 'package:drift/drift.dart';

import 'enums.dart';
import 'tables/entities.dart';
import 'tables/sync_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Households,
    Patients,
    Visits,
    Vitals,
    Outbox,
    SyncLog,
    Conflicts,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // One `if (from < N)` step per schema version.
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(syncMeta);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
