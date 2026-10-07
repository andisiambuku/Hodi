import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/seed.dart';
import 'package:hodi/core/sync/hlc.dart';
import 'package:hodi/core/sync/outbox_repository.dart';
import 'package:hodi/features/visits/data/visit_repository.dart';
import 'package:hodi/features/visits/domain/new_visit.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late VisitRepository visits;
  late DateTime clockNow;
  var nudges = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    clockNow = DateTime(2026, 10, 6, 9);
    nudges = 0;
    visits = VisitRepository(
      db,
      outbox,
      HlcClock(nodeId: 't', now: () => clockNow),
      nudge: () => nudges++,
      now: () => clockNow,
    );
    await seedDemoData(db, today: DateTime(2026, 10, 6));
  });
  tearDown(() => db.close());

  Future<Patient> anyPatient() async =>
      (await db.select(db.patients).get()).first;

  Future<String> record() async {
    final p = await anyPatient();
    clockNow = clockNow.add(const Duration(minutes: 1));
    return visits.recordVisit(
      NewVisit(
        patientId: p.id,
        patientName: p.fullName,
        visitType: 'Malaria test',
        scheduledAt: DateTime(2026, 10, 6, 14),
      ),
    );
  }

  Future<List<OutboxEntry>> entries() => outbox.watchPending().first;

  group('recordVisit', () {
    test('writes the visit and one added outbox entry together', () async {
      final id = await record();

      final v = await (db.select(
        db.visits,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(v.syncState, SyncState.pending);
      expect(v.serverVersion, 0);

      final e = (await entries()).single;
      expect(e.op, ChangeOp.added);
      expect(e.entityId, id);
      expect(e.status, OutboxStatus.queued);
      expect(e.label, startsWith('Visit: '));
      final payload = jsonDecode(e.payload) as Map;
      expect((payload['fields'] as Map)['visitType'], {
        'v': 'Malaria test',
        'hlc': v.hlc,
      });
      expect(nudges, 1);
    });

    test('is atomic: a failing outbox write rolls the visit back', () async {
      final p = await anyPatient();
      // Break the outbox so the second insert in the transaction fails.
      await db.customStatement('DROP TABLE outbox');
      await expectLater(
        visits.recordVisit(
          NewVisit(
            patientId: p.id,
            patientName: p.fullName,
            visitType: 'x',
            scheduledAt: DateTime(2026, 10, 6, 15),
          ),
        ),
        throwsA(anything),
      );
      expect(await db.select(db.visits).get(), hasLength(6));
      expect(nudges, 0);
    });

    test('outbox ids are unique and time-ordered (uuid v7)', () async {
      await record();
      await record();
      final ids = (await entries()).map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(2));
      expect([...ids]..sort(), ids);
    });
  });

  group('coalescing', () {
    test('edit of an unsent added folds into it', () async {
      final id = await record();
      await visits.editVisit(id, const VisitChanges(visitType: 'BP follow-up'));

      final e = (await entries()).single;
      expect(e.op, ChangeOp.added);
      final fields = (jsonDecode(e.payload) as Map)['fields'] as Map;
      expect((fields['visitType'] as Map)['v'], 'BP follow-up');
      expect(fields.containsKey('patientId'), isTrue);
    });

    test(
      'folded entry keeps its original createdAt (send order honest)',
      () async {
        final id = await record();
        final created = (await entries()).single.createdAt;
        clockNow = clockNow.add(const Duration(hours: 1));
        await visits.editVisit(id, const VisitChanges(visitType: 'Other'));
        expect((await entries()).single.createdAt, created);
      },
    );

    test('two edits of a synced visit merge into one edited entry', () async {
      final seeded = (await db.select(db.visits).get()).first;
      await visits.editVisit(
        seeded.id,
        const VisitChanges(visitType: 'Malaria test'),
      );
      await visits.editVisit(
        seeded.id,
        VisitChanges(scheduledAt: DateTime(2026, 10, 6, 16)),
      );
      await visits.editVisit(
        seeded.id,
        const VisitChanges(visitType: 'BP follow-up'),
      );

      final e = (await entries()).single;
      expect(e.op, ChangeOp.edited);
      final fields = (jsonDecode(e.payload) as Map)['fields'] as Map;
      expect((fields['visitType'] as Map)['v'], 'BP follow-up');
      expect(fields.containsKey('scheduledAt'), isTrue);
    });

    test(
      'per-field hlc is kept: later edit of one field stamps only it',
      () async {
        final seeded = (await db.select(db.visits).get()).first;
        await visits.editVisit(
          seeded.id,
          const VisitChanges(visitType: 'Malaria test'),
        );
        await visits.editVisit(
          seeded.id,
          VisitChanges(scheduledAt: DateTime(2026, 10, 6, 16)),
        );
        final fields =
            (jsonDecode((await entries()).single.payload) as Map)['fields']
                as Map;
        expect(
          (fields['visitType'] as Map)['hlc'],
          isNot((fields['scheduledAt'] as Map)['hlc']),
        );
      },
    );

    test('delete of an unsent added removes the entry and the visit', () async {
      final id = await record();
      await visits.deleteVisit(id);

      expect(await entries(), isEmpty);
      expect(
        await (db.select(db.visits)..where((t) => t.id.equals(id))).get(),
        isEmpty,
      );
    });

    test(
      'delete of a synced visit soft-deletes and queues one deleted',
      () async {
        final seeded = (await db.select(db.visits).get()).first;
        await visits.editVisit(
          seeded.id,
          const VisitChanges(visitType: 'Malaria test'),
        );
        await visits.deleteVisit(seeded.id);

        final e = (await entries()).single;
        expect(e.op, ChangeOp.deleted);
        final row = await (db.select(
          db.visits,
        )..where((t) => t.id.equals(seeded.id))).getSingle();
        expect(row.deleted, isTrue);
        expect(row.syncState, SyncState.pending);
      },
    );

    test('an in-flight entry is never folded into', () async {
      final id = await record();
      await (db.update(
        db.outbox,
      )).write(const OutboxCompanion(status: Value(OutboxStatus.inFlight)));
      await visits.editVisit(id, const VisitChanges(visitType: 'Other'));

      final all = await entries();
      expect(all.map((e) => e.op), [ChangeOp.added, ChangeOp.edited]);
    });

    test('acked entries are not pending', () async {
      await record();
      await db
          .update(db.outbox)
          .write(const OutboxCompanion(status: Value(OutboxStatus.acked)));
      expect(await entries(), isEmpty);
    });
  });

  group('pending list', () {
    test('is oldest first, and the count matches', () async {
      final a = await record();
      final b = await record();
      final c = await record();
      final list = await entries();
      expect(list.map((e) => e.entityId), [a, b, c]);
      expect(await outbox.watchPendingCount().first, 3);
    });

    test('failed entries stay visible', () async {
      await record();
      await db
          .update(db.outbox)
          .write(
            const OutboxCompanion(
              status: Value(OutboxStatus.failed),
              lastError: Value('rejected'),
            ),
          );
      expect((await entries()).single.status, OutboxStatus.failed);
    });
  });

  test('edits with no changes queue nothing', () async {
    final seeded = (await db.select(db.visits).get()).first;
    await visits.editVisit(seeded.id, const VisitChanges());
    expect(await entries(), isEmpty);
  });
}
