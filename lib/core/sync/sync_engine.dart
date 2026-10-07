import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/enums.dart';
import '../network/api_client.dart';
import 'change_applier.dart';
import 'entity_schema.dart';
import 'sync_meta_repository.dart';
import 'sync_progress.dart';
import 'sync_summary.dart';

enum SyncTrigger { auto, manual }

class SyncOutcome {
  const SyncOutcome({
    required this.result,
    this.sent = 0,
    this.received = 0,
    this.merged = 0,
    this.conflicts = 0,
    this.detail = const SyncSummary(SummaryKind.nothing),
    this.skipped = false,
  });

  /// Not run at all (offline). Nothing was logged.
  const SyncOutcome.skipped()
    : result = SyncRunResult.failed,
      sent = 0,
      received = 0,
      merged = 0,
      conflicts = 0,
      detail = const SyncSummary(SummaryKind.nothing),
      skipped = true;

  final SyncRunResult result;
  final int sent;
  final int received;

  /// Records where local and remote edits to different fields were combined.
  final int merged;

  /// Conflict cards raised for the nurse.
  final int conflicts;

  /// What happened, as data; the UI shows it in the nurse's language.
  final SyncSummary detail;
  final bool skipped;

  /// English text of [detail], for logs and tests.
  String get summary => detail.english;
}

/// pull → resolve → push → log. One run at a time.
///
/// Pull comes first on purpose: a change the phone hasn't sent yet can't have
/// been seen by whoever made a remote edit, so it is compared against the
/// remote edit before it is sent. If the pull fails nothing is pushed,
/// because pushing without resolving could silently overwrite someone's
/// clinical value.
class SyncEngine {
  SyncEngine({
    required this._db,
    required this._api,
    required this._applier,
    required this._meta,
    required this._deviceId,
    required this._isOnline,
    this.deviceName = _defaultDeviceName,
    this.onProgress,
    this.batchSize = 20,
    this.nudgeDebounce = const Duration(seconds: 1),
    this.logEmptyAutoRuns = false,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random(),
       _store = EntityStore(_db);

  static String _defaultDeviceName() => 'This phone';

  final AppDatabase _db;
  final ApiClient _api;
  final ChangeApplier _applier;
  final SyncMetaRepository _meta;
  final String _deviceId;
  final bool Function() _isOnline;
  final DateTime Function() _now;
  final Random _random;
  final EntityStore _store;

  /// Shown to other devices, e.g. "Clinic Tablet 2". Read at send time so a
  /// rename takes effect without restarting.
  final String Function() deviceName;
  final void Function(SyncProgress? progress)? onProgress;
  final int batchSize;
  final Duration nudgeDebounce;

  /// Quiet by default: a periodic run that found nothing isn't history.
  final bool logEmptyAutoRuns;

  /// 30 s, 1 m, 2 m, 5 m, then 15 m, each ±20 %.
  static const backoff = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  /// Wait before retry number [failures] (1-based), with ±20 % jitter.
  static Duration retryDelay(int failures, Random random) {
    final base = backoff[min(max(failures, 1) - 1, backoff.length - 1)];
    return base * (0.8 + random.nextDouble() * 0.4);
  }

  Future<SyncOutcome>? _running;
  Timer? _nudgeTimer;
  Timer? _retryTimer;
  int _failures = 0;
  bool _disposed = false;

  bool get isRunning => _running != null;

  /// Consecutive failed runs; drives the backoff.
  int get failureCount => _failures;

  /// A local write happened. Debounced; does nothing while offline (the
  /// reconnect trigger will pick it up).
  void nudge() {
    if (_disposed || !_isOnline()) return;
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(nudgeDebounce, () {
      if (_isOnline()) run();
    });
  }

  /// Entries left in flight by a killed app go back to the queue, and the
  /// interrupted attempt is recorded so history stays honest.
  Future<void> recoverInterrupted() async {
    final stuck = await (_db.select(
      _db.outbox,
    )..where((o) => o.status.equalsValue(OutboxStatus.inFlight))).get();
    if (stuck.isEmpty) return;
    await _db.transaction(() async {
      await (_db.update(_db.outbox)
            ..where((o) => o.status.equalsValue(OutboxStatus.inFlight)))
          .write(const OutboxCompanion(status: Value(OutboxStatus.queued)));
      final t = _now();
      await _db
          .into(_db.syncLog)
          .insert(
            SyncLogCompanion.insert(
              id: const Uuid().v7(),
              startedAt: t,
              finishedAt: Value(t),
              result: SyncRunResult.failed,
              summary: const SyncSummary(SummaryKind.interrupted).encode(),
            ),
          );
    });
  }

  /// Runs a sync unless one is already running (then joins it).
  Future<SyncOutcome> run({SyncTrigger trigger = SyncTrigger.auto}) {
    final current = _running;
    if (current != null) return current;
    if (_disposed || !_isOnline()) {
      return Future.value(const SyncOutcome.skipped());
    }
    final future = _run(trigger).whenComplete(() => _running = null);
    _running = future;
    return future;
  }

  Future<SyncOutcome> _run(SyncTrigger trigger) async {
    _nudgeTimer?.cancel();
    _retryTimer?.cancel();
    final startedAt = _now();
    var sent = 0;
    var pulled = const _PullResult();

    try {
      onProgress?.call(const SyncProgress(done: 0, total: 0));
      pulled = await _pull();
      sent = await _push();
      await _pruneAcked();

      _failures = 0;
      final merged = pulled.merged + pulled.conflicts > 0;
      final outcome = SyncOutcome(
        result: merged ? SyncRunResult.merged : SyncRunResult.done,
        sent: sent,
        received: pulled.received,
        merged: pulled.merged,
        conflicts: pulled.conflicts,
        detail: _summaryFor(sent, pulled),
      );
      final worthLogging =
          sent > 0 ||
          pulled.received > 0 ||
          trigger == SyncTrigger.manual ||
          logEmptyAutoRuns;
      if (worthLogging) await _log(startedAt, outcome);
      return outcome;
    } on ApiException catch (e) {
      return _fail(startedAt, sent, pulled.received, _summaryForError(e));
    } catch (e) {
      // A bug or local DB problem. Never print the message: it could hold PII.
      debugPrint('Sync failed locally: ${e.runtimeType}');
      return _fail(
        startedAt,
        sent,
        pulled.received,
        const SyncSummary(SummaryKind.local),
      );
    } finally {
      onProgress?.call(null);
    }
  }

  Future<SyncOutcome> _fail(
    DateTime startedAt,
    int sent,
    int received,
    SyncSummary detail,
  ) async {
    _failures++;
    final outcome = SyncOutcome(
      result: SyncRunResult.failed,
      sent: sent,
      received: received,
      detail: detail,
    );
    await _log(startedAt, outcome);
    _scheduleRetry();
    return outcome;
  }

  SyncSummary _summaryForError(ApiException e) => switch (e) {
    NetworkException() => const SyncSummary(SummaryKind.network),
    ServerException() => const SyncSummary(SummaryKind.server),
  };

  /// Stored on a requeued entry; the UI turns the code into words.
  String _errorCode(ApiException e) => switch (e) {
    NetworkException() => 'err:network',
    ServerException() => 'err:server',
  };

  SyncSummary _summaryFor(int sent, _PullResult pulled) {
    if (sent == 0 && pulled.received == 0) {
      return const SyncSummary(SummaryKind.nothing);
    }
    return SyncSummary(
      SummaryKind.synced,
      sent: sent,
      received: pulled.received,
      merged: pulled.merged,
      review: pulled.conflicts,
    );
  }

  Future<void> _log(DateTime startedAt, SyncOutcome o) => _db
      .into(_db.syncLog)
      .insert(
        SyncLogCompanion.insert(
          id: const Uuid().v7(),
          startedAt: startedAt,
          finishedAt: Value(_now()),
          result: o.result,
          sentCount: Value(o.sent),
          receivedCount: Value(o.received),
          summary: o.detail.encode(),
        ),
      );

  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay(_failures, _random), () {
      if (_isOnline()) run();
    });
  }

  // ── pull + resolve ──────────────────────────────────────────────────

  Future<_PullResult> _pull() async {
    final since = await _meta.readCursor();
    final page = await _api.changes(since: since, deviceId: _deviceId);

    var received = 0;
    var merged = 0;
    var conflicts = 0;
    for (final change in page.changes) {
      final outcome = await _applier.apply(change);
      received++;
      if (outcome.merged) merged++;
      conflicts += outcome.conflicts;
    }
    if (page.cursor != since) await _meta.writeCursor(page.cursor);
    return _PullResult(
      received: received,
      merged: merged,
      conflicts: conflicts,
    );
  }

  // ── push ────────────────────────────────────────────────────────────

  Future<int> _push() async {
    var done = 0;
    while (true) {
      final batch =
          await (_db.select(_db.outbox)
                ..where((o) => o.status.equalsValue(OutboxStatus.queued))
                ..orderBy([
                  (o) => OrderingTerm.asc(o.createdAt),
                  (o) => OrderingTerm.asc(o.id),
                ])
                ..limit(batchSize))
              .get();
      if (batch.isEmpty) return done;

      final remaining = await _countQueued();
      onProgress?.call(SyncProgress(done: done, total: done + remaining));

      final ids = batch.map((e) => e.id).toList();
      await (_db.update(_db.outbox)..where((o) => o.id.isIn(ids))).write(
        const OutboxCompanion(status: Value(OutboxStatus.inFlight)),
      );
      await _db.customUpdate(
        'UPDATE outbox SET attempts = attempts + 1 WHERE id IN (${List.filled(ids.length, '?').join(',')})',
        variables: [for (final id in ids) Variable.withString(id)],
        updates: {_db.outbox},
      );

      final List<PushResult> results;
      try {
        results = await _api.push(
          [for (final e in batch) _toItem(e)],
          deviceId: _deviceId,
          source: deviceName(),
        );
      } on ApiException catch (e) {
        // Lost network mid-sync: everything in flight goes back to the queue.
        await (_db.update(_db.outbox)..where((o) => o.id.isIn(ids))).write(
          OutboxCompanion(
            status: const Value(OutboxStatus.queued),
            lastError: Value(_errorCode(e)),
          ),
        );
        rethrow;
      }

      final byId = {for (final r in results) r.outboxId: r};
      await _db.transaction(() async {
        for (final entry in batch) {
          final r = byId[entry.id];
          if (r == null) {
            await (_db.update(
              _db.outbox,
            )..where((o) => o.id.equals(entry.id))).write(
              const OutboxCompanion(status: Value(OutboxStatus.queued)),
            );
          } else if (r.status == PushStatus.acked) {
            await _ack(entry, r.serverVersion);
          } else {
            await _reject(entry, r.error ?? 'err:rejected');
          }
        }
      });
      if (batch.any((e) => byId[e.id] == null)) {
        throw const ServerException(502); // incomplete answer: try again later
      }
      done += batch.length;
    }
  }

  Future<int> _countQueued() async {
    final count = _db.outbox.id.count();
    final q = _db.selectOnly(_db.outbox)
      ..addColumns([count])
      ..where(_db.outbox.status.equalsValue(OutboxStatus.queued));
    return (await q.map((r) => r.read(count)!).getSingle());
  }

  PushItem _toItem(OutboxEntry e) => PushItem(
    id: e.id,
    entityType: e.entityType,
    entityId: e.entityId,
    op: e.op,
    payload: (jsonDecode(e.payload) as Map).cast<String, Object?>(),
    createdAt: e.createdAt,
  );

  Future<void> _ack(OutboxEntry e, int serverVersion) async {
    await (_db.update(_db.outbox)..where((o) => o.id.equals(e.id))).write(
      const OutboxCompanion(status: Value(OutboxStatus.acked)),
    );
    if (_store.schemaFor(e.entityType) == null) return;

    // Other unsent changes keep the entity "waiting".
    final others = await _db
        .customSelect(
          'SELECT count(*) AS c FROM outbox WHERE entity_type = ? AND entity_id = ? AND status != ?',
          variables: [
            Variable.withString(e.entityType),
            Variable.withString(e.entityId),
            Variable.withString(OutboxStatus.acked.name),
          ],
          readsFrom: {_db.outbox},
        )
        .getSingle();

    if (e.op == ChangeOp.deleted && others.read<int>('c') == 0) {
      // Hard delete only after the server has acked.
      await _store.hardDelete(e.entityType, e.entityId);
      return;
    }
    await _store.update(
      e.entityType,
      e.entityId,
      const {},
      serverVersion: serverVersion,
    );
    await _store.refreshState(e.entityType, e.entityId);
  }

  Future<void> _reject(OutboxEntry e, String reason) async {
    await (_db.update(_db.outbox)..where((o) => o.id.equals(e.id))).write(
      OutboxCompanion(
        status: const Value(OutboxStatus.failed),
        lastError: Value(reason),
      ),
    );
    if (_store.schemaFor(e.entityType) == null) return;
    await _store.refreshState(e.entityType, e.entityId);
  }

  /// Acked entries have done their job.
  Future<void> _pruneAcked() => (_db.delete(
    _db.outbox,
  )..where((o) => o.status.equalsValue(OutboxStatus.acked))).go();

  void dispose() {
    _disposed = true;
    _nudgeTimer?.cancel();
    _retryTimer?.cancel();
  }
}

class _PullResult {
  const _PullResult({this.received = 0, this.merged = 0, this.conflicts = 0});

  final int received;
  final int merged;
  final int conflicts;
}
