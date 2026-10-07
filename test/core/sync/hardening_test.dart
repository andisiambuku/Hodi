import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/encrypted_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/key_store.dart';
import 'package:hodi/core/network/api_client.dart';
import 'package:hodi/core/sync/connectivity_service.dart';

import '../../support/sync_harness.dart';

/// Waits for [cond] on the real clock (these tests use real DB I/O).
Future<void> until(Future<bool> Function() cond, {int ms = 5000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!await cond()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for condition');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Starts a sync that the test will never wait for: the "process" is killed
/// by closing its database. A real kill takes the engine with it; here the
/// orphaned run just fails against the closed DB, and that is expected.
void _runUntilKilled(SyncHarness h) {
  unawaited(h.engine.run().then<void>((_) {}, onError: (Object _) {}));
}

void main() {
  late Directory dir;
  late File file;
  late InMemoryKeyStore keys;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hodi_hard');
    file = File('${dir.path}/hodi.sqlite');
    keys = InMemoryKeyStore();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<AppDatabase> openDb() async =>
      (await openEncryptedDatabase(keyStore: keys, file: file)).db;

  group('kill the app mid-sync', () {
    test(
      'killed after the server applied the push: nothing lost, nothing doubled',
      () async {
        final api = RecordingApi();
        final run1 = await SyncHarness.create(db: await openDb(), api: api);
        final ids = [
          for (var i = 0; i < 3; i++) await run1.recordVisit('Type $i'),
        ];
        api.hangAfterApply = true; // server applies, the phone never hears back

        _runUntilKilled(run1);
        await until(
          () async =>
              (await run1.db.select(run1.db.outbox).get()).every(
                (e) => e.status == OutboxStatus.inFlight,
              ) &&
              api.appliedPushCount == 3,
        );
        await run1.db.close(); // the process dies here

        // Next launch: same file, same key, same server.
        api.hangAfterApply = false;
        final db2 = await openDb();
        final run2 = await SyncHarness.create(db: db2, api: api, seed: false);
        addTearDown(run2.dispose);

        final stuck = await db2.select(db2.outbox).get();
        expect(stuck, hasLength(3)); // survived the kill
        await run2.engine.recoverInterrupted();
        expect(
          (await db2.select(db2.outbox).get()).every(
            (e) => e.status == OutboxStatus.queued,
          ),
          isTrue,
        );

        final outcome = await run2.engine.run();
        expect(outcome.result, SyncRunResult.done);
        expect(
          api.appliedPushCount,
          3,
          reason: 'replayed by idempotency key, not re-applied',
        );
        for (final id in ids) {
          expect(api.serverVersion('visit', id), 1);
        }
        expect(await db2.select(db2.outbox).get(), isEmpty);
        final visits = await db2.select(db2.visits).get();
        expect(
          visits
              .where((v) => ids.contains(v.id))
              .every((v) => v.syncState == SyncState.synced),
          isTrue,
        );

        // History tells the truth: an interrupted attempt, then a good one.
        final log = await db2.select(db2.syncLog).get();
        expect(
          log.map((r) => r.result),
          containsAll([SyncRunResult.failed, SyncRunResult.done]),
        );
      },
    );

    test(
      'killed before the server saw it: sent exactly once afterwards',
      () async {
        final api = RecordingApi();
        final run1 = await SyncHarness.create(db: await openDb(), api: api);
        await run1.recordVisit();
        api.hangBeforeApply = true;

        _runUntilKilled(run1);
        await until(
          () async => (await run1.db.select(run1.db.outbox).get()).any(
            (e) => e.status == OutboxStatus.inFlight,
          ),
        );
        await run1.db.close();

        api.hangBeforeApply = false;
        final db2 = await openDb();
        final run2 = await SyncHarness.create(db: db2, api: api, seed: false);
        addTearDown(run2.dispose);
        await run2.engine.recoverInterrupted();
        await run2.engine.run();

        expect(api.appliedPushCount, 1);
        expect(await db2.select(db2.outbox).get(), isEmpty);
      },
    );

    test(
      'a write made offline survives a kill and reboot (encrypted file)',
      () async {
        final run1 = await SyncHarness.create(
          db: await openDb(),
          isOnline: () => false,
        );
        final id = await run1.recordVisit('Offline visit');
        await run1.db.close();

        final db2 = await openDb();
        addTearDown(db2.close);
        final visit = await (db2.select(
          db2.visits,
        )..where((v) => v.id.equals(id))).getSingle();
        expect(visit.visitType, 'Offline visit');
        expect(visit.syncState, SyncState.pending);
        expect(await db2.select(db2.outbox).get(), hasLength(1));
      },
    );
  });

  group('airplane mode toggling', () {
    late StreamController<List<ConnectivityResult>> link;
    late List<ConnectivityResult> current;
    late ConnectivityService service;
    late SyncHarness h;
    final changes = <bool>[];

    setUp(() async {
      link = StreamController<List<ConnectivityResult>>.broadcast();
      current = [ConnectivityResult.wifi];
      changes.clear();
      service = ConnectivityService(
        linkChanges: link.stream,
        currentLink: () async => current,
        probe: () async => true,
        debounce: const Duration(milliseconds: 40),
        reprobeEvery: const Duration(hours: 1),
      );
      h = await SyncHarness.create(isOnline: () => service.isOnline);
      service.onChanged.listen((on) {
        changes.add(on);
        if (on) h.engine.run(); // the reconnect trigger
      });
      service.start();
      await until(() async => service.isOnline);
      changes.clear();
    });

    tearDown(() async {
      service.dispose();
      await link.close();
      await h.dispose();
    });

    void setLink(List<ConnectivityResult> r) {
      current = r;
      link.add(r);
    }

    test(
      '10 offline/online cycles with writes in between: all sent once, in order',
      () async {
        final ids = <String>[];
        for (var i = 0; i < 10; i++) {
          setLink([ConnectivityResult.none]);
          await until(() async => !service.isOnline);
          ids.add(await h.recordVisit('Cycle $i')); // offline: instant, local
          expect((await h.engine.run()).skipped, isTrue);

          setLink([ConnectivityResult.wifi]);
          await until(() async => service.isOnline);
          await until(
            () async => (await h.db.select(h.db.outbox).get()).isEmpty,
          );
        }

        expect(h.api.appliedPushCount, 10);
        for (final id in ids) {
          expect(h.api.serverVersion('visit', id), 1);
        }
        final order = h.api.batches
            .expand((b) => b)
            .map((i) => i.entityId)
            .toList();
        expect(order, ids);
      },
    );

    test('a sub-debounce flap never reaches the UI', () async {
      for (var i = 0; i < 20; i++) {
        setLink([ConnectivityResult.none]);
        await Future<void>.delayed(const Duration(milliseconds: 3));
        setLink([ConnectivityResult.wifi]);
        await Future<void>.delayed(const Duration(milliseconds: 3));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(service.isOnline, isTrue);
      expect(changes, isEmpty);
    });

    test(
      'losing the network mid-push requeues, then reconnecting finishes it',
      () async {
        final id = await h.recordVisit();
        h.api.failNext(1, const NetworkException());

        final first = await h.engine.run();
        expect(first.result, SyncRunResult.failed);
        setLink([ConnectivityResult.none]);
        await until(() async => !service.isOnline);
        expect(
          (await h.db.select(h.db.outbox).get()).single.status,
          OutboxStatus.queued,
        );

        setLink([ConnectivityResult.wifi]);
        await until(() async => service.isOnline);
        await until(() async => (await h.db.select(h.db.outbox).get()).isEmpty);
        expect(h.api.serverVersion('visit', id), 1);
        expect(h.api.appliedPushCount, 1);
      },
    );
  });

  group('500 queued changes', () {
    test(
      'records, lists and syncs in reasonable time on the encrypted DB',
      () async {
        final h = await SyncHarness.create(db: await openDb());
        addTearDown(h.dispose);

        final writes = Stopwatch()..start();
        final ids = <String>[];
        for (var i = 0; i < 500; i++) {
          ids.add(await h.recordVisit('Bulk $i'));
        }
        writes.stop();

        final list = Stopwatch()..start();
        final pending = await h.outbox.watchPending().first;
        list.stop();
        expect(pending, hasLength(500));

        final sync = Stopwatch()..start();
        final outcome = await h.engine.run();
        sync.stop();

        // ignore: avoid_print
        print(
          '500 changes: write ${writes.elapsedMilliseconds}ms '
          '(${(writes.elapsedMilliseconds / 500).toStringAsFixed(1)}ms each), '
          'list ${list.elapsedMilliseconds}ms, sync ${sync.elapsedMilliseconds}ms',
        );

        expect(outcome.sent, 500);
        expect(h.api.batches.map((b) => b.length), [
          for (var i = 0; i < 25; i++) 20,
        ]);
        expect(h.api.appliedPushCount, 500);
        expect(await h.db.select(h.db.outbox).get(), isEmpty);
        expect(
          await h.api.changes(deviceId: 'other').then((p) => p.changes.length),
          500,
        );

        // Generous ceilings: they catch accidental O(n²), not machine speed.
        expect(
          writes.elapsedMilliseconds / 500,
          lessThan(50),
          reason: 'a write must feel instant',
        );
        expect(list.elapsedMilliseconds, lessThan(1000));
        expect(sync.elapsedMilliseconds, lessThan(20000));
      },
    );
  });
}
