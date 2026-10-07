import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/sync/sync_engine.dart';
import 'package:hodi/features/visits/domain/new_visit.dart';

import '../../support/l10n.dart';
import '../../support/sync_harness.dart';

void main() {
  late SyncHarness h;

  setUp(() async => h = await SyncHarness.create());
  tearDown(() => h.dispose());

  Future<List<SyncRun>> runs() => (h.db.select(h.db.syncLog)).get();
  Future<List<OutboxEntry>> outboxRows() => h.db.select(h.db.outbox).get();

  group('push', () {
    test(
      'acks entries, marks the visit synced, stores serverVersion, logs it',
      () async {
        final id = await h.recordVisit();
        final outcome = await h.engine.run();

        expect(outcome.result, SyncRunResult.done);
        expect(outcome.sent, 1);
        final v = await (h.db.select(
          h.db.visits,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(v.syncState, SyncState.synced);
        expect(v.serverVersion, 1);
        expect(h.api.serverValue('visit', id, 'visitType'), 'Malaria test');
        expect(await outboxRows(), isEmpty); // acked entries are pruned

        final log = (await runs()).single;
        expect(log.result, SyncRunResult.done);
        expect(log.sentCount, 1);
        expect(summaryText(log.summary), '1 change sent, 0 received');
      },
    );

    test('sends oldest first, in batches of 20', () async {
      final ids = <String>[];
      for (var i = 0; i < 45; i++) {
        ids.add(await h.recordVisit('Type $i'));
      }
      await h.engine.run();

      expect(h.api.batches.map((b) => b.length), [20, 20, 5]);
      final sentOrder = h.api.batches.expand((b) => b).map((i) => i.entityId);
      expect(sentOrder.toList(), ids);
    });

    test('progress runs x of N and ends cleared', () async {
      for (var i = 0; i < 3; i++) {
        await h.recordVisit();
      }
      await h.engine.run();

      final seen = h.progress.whereType<dynamic>().toList();
      expect(h.progress.last, isNull);
      expect(seen.any((p) => p.total == 3), isTrue);
      expect(h.progress.first!.done, 0);
    });

    test(
      'a delete of a synced visit purges the row only after the ack',
      () async {
        final v = await h.seededVisit();
        await h.visits.deleteVisit(v.id);
        expect(
          await (h.db.select(
            h.db.visits,
          )..where((t) => t.id.equals(v.id))).get(),
          hasLength(1), // soft-deleted, still on the phone
        );
        await h.engine.run();
        expect(
          await (h.db.select(
            h.db.visits,
          )..where((t) => t.id.equals(v.id))).get(),
          isEmpty,
        );
        expect(h.api.serverDeleted('visit', v.id), isTrue);
      },
    );

    test(
      'an edit that arrives with other changes pending keeps the row Waiting',
      () async {
        final id = await h.recordVisit();
        // Simulate: added is acked, but a newer edit is queued meanwhile.
        await h.engine.run();
        await h.visits.editVisit(
          id,
          const VisitChanges(visitType: 'BP follow-up'),
        );
        final v = await (h.db.select(
          h.db.visits,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(v.syncState, SyncState.pending);
      },
    );
  });

  group('failures', () {
    test(
      'a lost response then a retry never duplicates (idempotency key)',
      () async {
        final id = await h.recordVisit();
        h.api.dropNextResponses(1);

        final first = await h.engine.run();
        expect(first.result, SyncRunResult.failed);
        expect(first.summary, "Couldn't reach the server. Will retry.");
        // The server applied it, but the phone doesn't know: still queued.
        final queued = (await outboxRows()).single;
        expect(queued.status, OutboxStatus.queued);
        expect(queued.attempts, 1);
        expect(h.api.appliedPushCount, 1);

        final second = await h.engine.run();
        expect(second.result, SyncRunResult.done);
        expect(h.api.appliedPushCount, 1); // replayed, not re-applied
        expect(h.api.serverVersion('visit', id), 1);
        expect(await outboxRows(), isEmpty);
      },
    );

    test(
      'a 5xx fails the run in plain language and leaves entries queued',
      () async {
        await h.recordVisit();
        h.api.failNext(1);
        final outcome = await h.engine.run();

        expect(outcome.result, SyncRunResult.failed);
        expect(outcome.summary, "Server didn't respond. Will retry.");
        expect((await outboxRows()).single.status, OutboxStatus.queued);
        final log = (await runs()).single;
        expect(log.result, SyncRunResult.failed);
        expect(h.engine.failureCount, 1);
      },
    );

    test('a success resets the failure count', () async {
      await h.recordVisit();
      h.api.failNext(2);
      await h.engine.run();
      await h.engine.run();
      expect(h.engine.failureCount, 2);
      await h.engine.run();
      expect(h.engine.failureCount, 0);
    });

    test('a rejected entry fails alone and does not block the rest', () async {
      final bad = await h.recordVisit('Bad type');
      final good = await h.recordVisit('Good type');
      h.api.rejectWhen = (i) =>
          i.entityId == bad ? 'Visit type not allowed.' : null;

      final outcome = await h.engine.run();
      expect(outcome.result, SyncRunResult.done);

      final rows = await outboxRows();
      expect(rows.single.entityId, bad);
      expect(rows.single.status, OutboxStatus.failed);
      expect(rows.single.lastError, 'Visit type not allowed.');
      final goodRow = await (h.db.select(
        h.db.visits,
      )..where((t) => t.id.equals(good))).getSingle();
      final badRow = await (h.db.select(
        h.db.visits,
      )..where((t) => t.id.equals(bad))).getSingle();
      expect(goodRow.syncState, SyncState.synced);
      expect(badRow.syncState, SyncState.failed);
    });

    test('a failed (rejected) entry is not retried on the next run', () async {
      final bad = await h.recordVisit();
      h.api.rejectWhen = (i) => i.entityId == bad ? 'No.' : null;
      await h.engine.run();
      h.api.rejectWhen = null;
      await h.engine.run();
      expect((await outboxRows()).single.status, OutboxStatus.failed);
      expect(h.api.appliedPushCount, 0);
    });

    test('backoff: 30s, 1m, 2m, 5m, then capped at 15m, with ±20% jitter', () {
      final mid = _FixedRandom(0.5); // jitter factor exactly 1.0
      Duration d(int n) => SyncEngine.retryDelay(n, mid);
      expect(
        [for (var i = 1; i <= 7; i++) d(i)],
        [
          const Duration(seconds: 30),
          const Duration(minutes: 1),
          const Duration(minutes: 2),
          const Duration(minutes: 5),
          const Duration(minutes: 15),
          const Duration(minutes: 15),
          const Duration(minutes: 15),
        ],
      );
      final lo = SyncEngine.retryDelay(1, _FixedRandom(0));
      final hi = SyncEngine.retryDelay(1, _FixedRandom(0.999999));
      expect(lo, const Duration(seconds: 24));
      expect(hi.inMilliseconds, inInclusiveRange(35900, 36000));
    });
  });

  group('pull', () {
    test('applies a remote edit, counts it, and persists the cursor', () async {
      final v = await h.seededVisit();
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: v.id,
        fields: {'visitType': 'Home visit'},
      );
      final outcome = await h.engine.run();

      expect(outcome.received, 1);
      final after = await (h.db.select(
        h.db.visits,
      )..where((t) => t.id.equals(v.id))).getSingle();
      expect(after.visitType, 'Home visit');
      expect(after.syncState, SyncState.synced);
      expect(await h.meta.readCursor(), isNotNull);

      final again = await h.engine.run(trigger: SyncTrigger.manual);
      expect(again.received, 0); // not re-delivered
    });

    test('creates a visit that exists only on the server', () async {
      final p = (await h.db.select(h.db.patients).get()).first;
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: 'remote-visit-1',
        op: ChangeOp.added,
        fields: {
          'patientId': p.id,
          'patientName': p.fullName,
          'visitType': 'Malaria test',
          'scheduledAt': DateTime(2026, 10, 6, 16).toUtc().toIso8601String(),
        },
      );
      await h.engine.run();
      final v = await (h.db.select(
        h.db.visits,
      )..where((t) => t.id.equals('remote-visit-1'))).getSingle();
      expect(v.scheduledAt, DateTime(2026, 10, 6, 16));
      expect(v.syncState, SyncState.synced);
    });

    test("doesn't receive its own pushes back", () async {
      await h.recordVisit();
      final outcome = await h.engine.run();
      expect(outcome.sent, 1);
      expect(outcome.received, 0);
    });

    test(
      'a rejected local edit is still compared with a remote edit, not lost',
      () async {
        final v = await h.seededVisit();
        await h.visits.editVisit(
          v.id,
          const VisitChanges(visitType: 'My edit'),
        );
        h.api.rejectWhen = (_) => 'Rejected.';
        await h.engine.run(); // our edit is rejected and stays unacked
        h.remoteNow = DateTime(2026, 10, 6, 12);
        h.api.injectRemoteEdit(
          entityType: 'visit',
          entityId: v.id,
          fields: {'visitType': 'Their edit'},
        );

        await h.engine.run();
        final after = await (h.db.select(
          h.db.visits,
        )..where((t) => t.id.equals(v.id))).getSingle();
        expect(after.visitType, 'Their edit'); // newer, and we have the card
        expect(await h.conflicts.watchUnresolved().first, hasLength(1));
      },
    );

    test('a push failure after a good pull keeps what was pulled', () async {
      final v = await h.seededVisit();
      await h.recordVisit();
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: v.id,
        fields: {'visitType': 'Home visit'},
      );
      h.api.breakPush = true;

      final outcome = await h.engine.run();
      expect(outcome.result, SyncRunResult.failed);
      expect(outcome.received, 1);
      final after = await (h.db.select(
        h.db.visits,
      )..where((t) => t.id.equals(v.id))).getSingle();
      expect(after.visitType, 'Home visit');
      expect(await h.meta.readCursor(), isNotNull);
      expect((await outboxRows()).single.status, OutboxStatus.queued);

      h.api.breakPush = false;
      final retry = await h.engine.run();
      expect(retry.sent, 1);
      expect(retry.received, 0); // not delivered twice
    });
  });

  group('running', () {
    test(
      'works while UI-style stream watchers are live (no deadlock)',
      () async {
        final subs = [
          h.outbox.watchPending().listen((_) {}),
          h.outbox.watchSendableCount().listen((_) {}),
        ];
        await h.recordVisit();
        final outcome = await h.engine.run().timeout(
          const Duration(seconds: 5),
        );
        expect(outcome.result, SyncRunResult.done);
        for (final s in subs) {
          await s.cancel();
        }
      },
    );

    test(
      'only one run at a time: concurrent calls share the same run',
      () async {
        await h.recordVisit();
        final a = h.engine.run();
        final b = h.engine.run();
        expect(identical(a, b), isTrue);
        await Future.wait([a, b]);
        expect(h.api.appliedPushCount, 1);
      },
    );

    test('offline: skipped and nothing logged', () async {
      await h.recordVisit();
      h.online = false;
      final outcome = await h.engine.run();
      expect(outcome.skipped, isTrue);
      expect(await runs(), isEmpty);
      expect((await outboxRows()).single.status, OutboxStatus.queued);
    });

    test('an empty automatic run is not history; a manual one is', () async {
      await h.engine.run();
      expect(await runs(), isEmpty);
      await h.engine.run(trigger: SyncTrigger.manual);
      final log = await runs();
      expect(summaryText(log.single.summary), 'Nothing new to sync');
      expect(log.single.result, SyncRunResult.done);
    });

    test(
      'recoverInterrupted returns in-flight entries to the queue and says so',
      () async {
        await h.recordVisit();
        await h.db
            .update(h.db.outbox)
            .write(const OutboxCompanion(status: Value(OutboxStatus.inFlight)));
        await h.engine.recoverInterrupted();

        expect((await outboxRows()).single.status, OutboxStatus.queued);
        final log = (await runs()).single;
        expect(log.result, SyncRunResult.failed);
        expect(summaryText(log.summary), 'Sync was interrupted. Will retry.');

        final outcome = await h.engine.run();
        expect(outcome.sent, 1); // and it goes through
      },
    );

    test('recoverInterrupted with nothing stuck logs nothing', () async {
      await h.engine.recoverInterrupted();
      expect(await runs(), isEmpty);
    });
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.v);

  final double v;

  @override
  double nextDouble() => v;

  @override
  bool nextBool() => v > 0.5;

  @override
  int nextInt(int max) => (v * max).floor();
}
