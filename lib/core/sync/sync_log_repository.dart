import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/enums.dart';

class SyncLogRepository {
  SyncLogRepository(this._db);

  final AppDatabase _db;

  /// When the last non-failed sync finished; null if there hasn't been one.
  Stream<DateTime?> watchLastSyncedAt() =>
      (_db.select(_db.syncLog)
            ..where((r) => r.result.equalsValue(SyncRunResult.failed).not())
            ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
            ..limit(1))
          .watch()
          .map(
            (rows) => rows.isEmpty
                ? null
                : rows.first.finishedAt ?? rows.first.startedAt,
          );

  /// Keep the last 30 days of history.
  Future<int> pruneOlderThan(DateTime cutoff) => (_db.delete(
    _db.syncLog,
  )..where((r) => r.startedAt.isSmallerThanValue(cutoff))).go();

  Stream<List<SyncRun>> watchRecent({int limit = 100}) =>
      (_db.select(_db.syncLog)
            ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
            ..limit(limit))
          .watch();

  /// Total / done / merged / failed over everything in the log.
  Stream<SyncStats> watchStats() {
    final count = _db.syncLog.id.count();
    final q = _db.selectOnly(_db.syncLog)
      ..addColumns([_db.syncLog.result, count])
      ..groupBy([_db.syncLog.result]);
    return q.watch().map((rows) {
      int of(SyncRunResult r) => rows
          .where((row) => row.read(_db.syncLog.result) == r.name)
          .map((row) => row.read(count)!)
          .fold(0, (a, b) => a + b);
      final done = of(SyncRunResult.done);
      final merged = of(SyncRunResult.merged);
      final failed = of(SyncRunResult.failed);
      return SyncStats(
        total: done + merged + failed,
        done: done,
        merged: merged,
        failed: failed,
      );
    });
  }
}

class SyncStats {
  const SyncStats({
    required this.total,
    required this.done,
    required this.merged,
    required this.failed,
  });

  final int total;
  final int done;
  final int merged;
  final int failed;
}
