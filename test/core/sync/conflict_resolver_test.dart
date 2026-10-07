import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/db/app_database.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/sync/entity_schema.dart';
import 'package:hodi/core/sync/hlc.dart';
import 'package:hodi/features/visits/domain/new_visit.dart';
import 'package:hodi/features/visits/presentation/conflict_copy.dart';

import '../../support/l10n.dart';

import '../../support/sync_harness.dart';

ConflictCopy copyOf(Conflict c) => describeConflict(en, 'en', c);

void main() {
  late SyncHarness h;

  setUp(() async => h = await SyncHarness.create());
  tearDown(() => h.dispose());

  final earlier = DateTime(2026, 10, 6, 8);
  final later = DateTime(2026, 10, 6, 10);

  Future<Visit> visit(String id) =>
      (h.db.select(h.db.visits)..where((v) => v.id.equals(id))).getSingle();
  Future<Vital> vital(String id) =>
      (h.db.select(h.db.vitals)..where((v) => v.id.equals(id))).getSingle();
  Future<List<OutboxEntry>> outbox() => h.db.select(h.db.outbox).get();

  /// A visit and its vitals, created at 07:00 and already on the server.
  Future<({String visitId, String vitalsId})> vitalsOnServer() async {
    h.now = DateTime(2026, 10, 6, 7);
    final v = await h.seededVisit();
    final vitalsId = await h.syncedVitals(v.id);
    h.now = DateTime(2026, 10, 6, 9); // local edits happen at 09:00
    return (visitId: v.id, vitalsId: vitalsId);
  }

  group('different fields: merge', () {
    test(
      'keeps both edits, notes the merge, pushes ours, logs a merged sync',
      () async {
        final v = await h.seededVisit();
        await h.visits.editVisit(
          v.id,
          const VisitChanges(visitType: 'Malaria test'),
        );
        h.remoteNow = later;
        final remoteTime = DateTime(2026, 10, 6, 16, 30);
        h.api.injectRemoteEdit(
          entityType: 'visit',
          entityId: v.id,
          fields: {'scheduledAt': remoteTime.toUtc().toIso8601String()},
        );

        final outcome = await h.engine.run();

        final row = await visit(v.id);
        expect(row.visitType, 'Malaria test'); // ours
        expect(row.scheduledAt, remoteTime); // theirs
        expect(h.api.serverValue('visit', v.id, 'visitType'), 'Malaria test');
        expect(row.syncState, SyncState.synced); // a merge is not a problem

        final notices = await h.unresolved();
        expect(notices, hasLength(1));
        expect(notices.single.kind, ConflictKind.merged);
        expect(notices.single.remoteSource, 'Clinic Tablet 2');
        expect(
          copyOf(notices.single).title,
          'Merged a change from Clinic Tablet 2',
        );
        expect(
          copyOf(notices.single).body,
          "Amina Wanjiru's visit now has both edits.",
        );

        expect(outcome.result, SyncRunResult.merged);
        final log = (await h.db.select(h.db.syncLog).get()).single;
        expect(log.result, SyncRunResult.merged);
        expect(summaryText(log.summary), contains('1 merged'));
      },
    );

    test('dismissing the banner resolves it and never changes data', () async {
      final v = await h.seededVisit();
      await h.visits.editVisit(
        v.id,
        const VisitChanges(visitType: 'Malaria test'),
      );
      h.remoteNow = later;
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: v.id,
        fields: {
          'scheduledAt': DateTime(2026, 10, 6, 16).toUtc().toIso8601String(),
        },
      );
      await h.engine.run();
      final notice = (await h.unresolved()).single;
      await h.conflicts.accept(notice.id);

      expect(await h.unresolved(), isEmpty);
      expect((await visit(v.id)).visitType, 'Malaria test');
    });
  });

  group('same field', () {
    test(
      'remote newer: remote kept, our value stored, card raised, old edit not sent',
      () async {
        final v = await h.seededVisit();
        await h.visits.editVisit(
          v.id,
          const VisitChanges(visitType: 'Malaria test'),
        );
        h.remoteNow = later;
        h.api.injectRemoteEdit(
          entityType: 'visit',
          entityId: v.id,
          fields: {'visitType': 'Home visit'},
        );
        await h.engine.run();

        final row = await visit(v.id);
        expect(row.visitType, 'Home visit');
        expect(row.syncState, SyncState.conflict); // shows ⚠ Needs review
        expect(h.api.serverValue('visit', v.id, 'visitType'), 'Home visit');
        expect(await outbox(), isEmpty); // our replaced edit was not pushed

        final card = (await h.unresolved()).single;
        expect(card.kind, ConflictKind.replaced);
        expect(card.field, 'visitType');
        expect(EntityStore.decodeValue(card.localValue), 'Malaria test');
        expect(EntityStore.decodeValue(card.remoteValue), 'Home visit');
      },
    );

    test(
      'local newer, non-clinical: ours wins silently and is pushed',
      () async {
        final v = await h.seededVisit();
        await h.visits.editVisit(
          v.id,
          const VisitChanges(visitType: 'Malaria test'),
        );
        h.remoteNow = earlier;
        h.api.injectRemoteEdit(
          entityType: 'visit',
          entityId: v.id,
          fields: {'visitType': 'Home visit'},
        );
        await h.engine.run();

        expect((await visit(v.id)).visitType, 'Malaria test');
        expect(h.api.serverValue('visit', v.id, 'visitType'), 'Malaria test');
        expect(await h.unresolved(), isEmpty);
      },
    );

    test('both sides already agree: nothing to show', () async {
      final v = await h.seededVisit();
      await h.visits.editVisit(
        v.id,
        const VisitChanges(visitType: 'Malaria test'),
      );
      h.remoteNow = later;
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: v.id,
        fields: {'visitType': 'Malaria test'},
      );
      await h.engine.run();
      expect(await h.unresolved(), isEmpty);
    });
  });

  group('clinical safety', () {
    // Every clinical field, in both directions: a visible card, always.
    const cases = [
      ('temperatureC', 38.4, 37.9),
      ('systolic', 140, 150),
      ('diastolic', 95, 100),
    ];
    for (final (field, mine, theirs) in cases) {
      for (final remoteNewer in [true, false]) {
        test(
          '$field, ${remoteNewer ? 'remote' : 'local'} newer → a card, never silent',
          () async {
            final ids = await vitalsOnServer();
            await h.vitals.save(
              ids.visitId,
              temperatureC: field == 'temperatureC' ? mine as double : null,
              systolic: field == 'systolic' ? mine as int : null,
              diastolic: field == 'diastolic' ? mine as int : null,
            );
            h.remoteNow = remoteNewer ? later : earlier;
            h.api.injectRemoteEdit(
              entityType: 'vitals',
              entityId: ids.vitalsId,
              fields: {field: theirs},
            );
            await h.engine.run();

            final cards = (await h.unresolved())
                .where((c) => c.kind != ConflictKind.merged)
                .toList();
            expect(cards, hasLength(1));
            expect(cards.single.field, field);
            expect(
              cards.single.kind,
              remoteNewer ? ConflictKind.replaced : ConflictKind.localKept,
            );
            expect(EntityStore.decodeValue(cards.single.localValue), mine);
            expect(EntityStore.decodeValue(cards.single.remoteValue), theirs);
            expect((await vital(ids.vitalsId)).syncState, SyncState.conflict);
          },
        );
      }
    }

    test(
      'a remote clinical edit with no local edit just applies (nothing overwritten)',
      () async {
        final ids = await vitalsOnServer();
        h.remoteNow = later;
        h.api.injectRemoteEdit(
          entityType: 'vitals',
          entityId: ids.vitalsId,
          fields: {'temperatureC': 37.9},
        );
        await h.engine.run();
        expect((await vital(ids.vitalsId)).temperatureC, 37.9);
        expect(await h.unresolved(), isEmpty);
      },
    );

    test('card copy matches the spec template exactly', () async {
      final ids = await vitalsOnServer();
      await h.vitals.save(ids.visitId, temperatureC: 38.4);
      h.remoteNow = later;
      h.api.injectRemoteEdit(
        entityType: 'vitals',
        entityId: ids.vitalsId,
        fields: {'temperatureC': 37.9},
      );
      await h.engine.run();

      final copy = copyOf((await h.unresolved()).single);
      expect(copy.title, 'One of your edits was replaced');
      expect(
        copy.body,
        "You changed Amina Wanjiru's temperature to 38.4 °C. "
        'A newer edit from Clinic Tablet 2 set it to 37.9 °C, '
        'so that value was kept.',
      );
      expect(copy.primary!.label, 'Re-enter mine');
      expect(copy.secondary!.label, 'Keep newer');
    });
  });

  group('actions', () {
    Future<({String visitId, String vitalsId, Conflict card})>
    replacedCard() async {
      final ids = await vitalsOnServer();
      await h.vitals.save(ids.visitId, temperatureC: 38.4);
      h.remoteNow = later;
      h.api.injectRemoteEdit(
        entityType: 'vitals',
        entityId: ids.vitalsId,
        fields: {'temperatureC': 37.9},
      );
      await h.engine.run();
      return (
        visitId: ids.visitId,
        vitalsId: ids.vitalsId,
        card: (await h.unresolved()).single,
      );
    }

    test(
      'Re-enter mine: a new edit with a fresh HLC, through the outbox',
      () async {
        final c = await replacedCard();
        final before = (await vital(c.vitalsId)).hlc;
        await h.conflicts.reenterMine(c.card.id);

        final row = await vital(c.vitalsId);
        expect(row.temperatureC, 38.4);
        expect(row.hlc.compareTo(before), greaterThan(0));
        expect(row.syncState, SyncState.pending);
        final queued = (await outbox()).single;
        expect(queued.op, ChangeOp.edited);
        expect(queued.label, 'Vitals: Amina Wanjiru');
        expect(await h.unresolved(), isEmpty);

        await h.engine.run();
        expect(h.api.serverValue('vitals', c.vitalsId, 'temperatureC'), 38.4);
        expect((await vital(c.vitalsId)).syncState, SyncState.synced);
        expect(await h.unresolved(), isEmpty); // and it doesn't conflict again
      },
    );

    test(
      'Keep newer: resolves with no write, row goes back to synced',
      () async {
        final c = await replacedCard();
        await h.conflicts.accept(c.card.id);

        expect(await h.unresolved(), isEmpty);
        expect(await outbox(), isEmpty);
        final row = await vital(c.vitalsId);
        expect(row.temperatureC, 37.9);
        expect(row.syncState, SyncState.synced);
      },
    );

    test(
      'unresolved cards survive a restart (new repository, same DB)',
      () async {
        await replacedCard();
        final reopened = await h.conflicts.watchUnresolved().first;
        expect(reopened.single.kind, ConflictKind.replaced);
      },
    );

    test(
      'Use theirs on a kept-clinical card writes the other value as a new edit',
      () async {
        final ids = await vitalsOnServer();
        await h.vitals.save(ids.visitId, temperatureC: 38.4);
        h.remoteNow = earlier;
        h.api.injectRemoteEdit(
          entityType: 'vitals',
          entityId: ids.vitalsId,
          fields: {'temperatureC': 37.9},
        );
        await h.engine.run();
        final card = (await h.unresolved()).single;
        expect(card.kind, ConflictKind.localKept);
        expect((await vital(ids.vitalsId)).temperatureC, 38.4);

        await h.conflicts.useTheirs(card.id);
        expect((await vital(ids.vitalsId)).temperatureC, 37.9);
        await h.engine.run();
        expect(h.api.serverValue('vitals', ids.vitalsId, 'temperatureC'), 37.9);
      },
    );
  });

  group('deletes', () {
    test(
      'remote delete + local edit: we keep ours, re-create it, and ask',
      () async {
        final v = await h.seededVisit();
        await h.visits.editVisit(
          v.id,
          const VisitChanges(visitType: 'Malaria test'),
        );
        h.remoteNow = later;
        h.api.injectRemoteEdit(
          entityType: 'visit',
          entityId: v.id,
          fields: const {},
          op: ChangeOp.deleted,
        );
        await h.engine.run();

        expect((await visit(v.id)).visitType, 'Malaria test'); // still here
        expect(h.api.serverDeleted('visit', v.id), isFalse); // re-created
        final card = (await h.unresolved()).single;
        expect(card.kind, ConflictKind.deletedRemotely);
        expect(copyOf(card).primary!.label, 'Keep mine');
        expect(copyOf(card).secondary!.label, 'Delete it');
      },
    );

    test('"Delete it" agrees with the deletion and it syncs', () async {
      final v = await h.seededVisit();
      await h.visits.editVisit(
        v.id,
        const VisitChanges(visitType: 'Malaria test'),
      );
      h.remoteNow = later;
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: v.id,
        fields: const {},
        op: ChangeOp.deleted,
      );
      await h.engine.run();
      final card = (await h.unresolved()).single;

      await h.conflicts.deleteIt(card.id);
      await h.engine.run();
      expect(
        await (h.db.select(h.db.visits)..where((t) => t.id.equals(v.id))).get(),
        isEmpty,
      );
      expect(h.api.serverDeleted('visit', v.id), isTrue);
    });

    test('remote delete with no local edits just removes it', () async {
      final v = await h.seededVisit();
      h.remoteNow = later;
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: v.id,
        fields: const {},
        op: ChangeOp.deleted,
      );
      await h.engine.run();
      expect(
        await (h.db.select(h.db.visits)..where((t) => t.id.equals(v.id))).get(),
        isEmpty,
      );
      expect(await h.unresolved(), isEmpty);
    });

    test(
      'we deleted, they edited: our delete stands, nothing is overwritten',
      () async {
        final v = await h.seededVisit();
        await h.visits.deleteVisit(v.id);
        h.remoteNow = later;
        h.api.injectRemoteEdit(
          entityType: 'visit',
          entityId: v.id,
          fields: {'visitType': 'Home visit'},
        );
        await h.engine.run();
        expect(h.api.serverDeleted('visit', v.id), isTrue);
        expect(
          await (h.db.select(
            h.db.visits,
          )..where((t) => t.id.equals(v.id))).get(),
          isEmpty,
        );
      },
    );
  });

  group('engine order', () {
    test('a failed pull blocks the push (never push unresolved)', () async {
      final v = await h.seededVisit();
      await h.visits.editVisit(
        v.id,
        const VisitChanges(visitType: 'Malaria test'),
      );
      h.api.breakChanges = true;

      final outcome = await h.engine.run();
      expect(outcome.result, SyncRunResult.failed);
      expect(h.api.appliedPushCount, 0);
      expect((await outbox()).single.status, OutboxStatus.queued);
    });

    test('later local stamps sort after a remote one we received', () async {
      final v = await h.seededVisit();
      h.remoteNow = DateTime(2030, 1, 1); // far future
      h.api.injectRemoteEdit(
        entityType: 'visit',
        entityId: v.id,
        fields: {'visitType': 'Home visit'},
      );
      await h.engine.run();
      final remote = Hlc.parse(h.clock.next());
      expect(
        remote.ms,
        greaterThanOrEqualTo(DateTime(2030, 1, 1).millisecondsSinceEpoch),
      );
    });
  });

  group('patient account status', () {
    Future<Patient> patient() async =>
        (await h.db.select(h.db.patients).get()).first;

    for (final remoteWins in [true, false]) {
      test('two nurses offline: ${remoteWins ? 'newer remote' : 'newer local'} '
          'wins and the other gets a card', () async {
        final p = await patient();
        h.now = DateTime(2026, 10, 6, 9);
        await h.patients.setAccountStatus(p.id, AccountStatus.inactive);
        h.remoteNow = remoteWins ? later : DateTime(2026, 10, 6, 8);
        h.api.injectRemoteEdit(
          entityType: 'patient',
          entityId: p.id,
          fields: {'accountStatus': 'active'},
        );

        await h.engine.run();

        final cards = await h.unresolved();
        expect(cards, hasLength(1));
        expect(
          cards.single.kind,
          remoteWins ? ConflictKind.replaced : ConflictKind.localKept,
        );
        expect(cards.single.fieldLabel, 'account status');
        final row = await patient();
        expect(
          row.accountStatus,
          remoteWins ? AccountStatus.active : AccountStatus.inactive,
        );
        expect(copyOf(cards.single).body, contains('Inactive'));
        expect(copyOf(cards.single).body, contains('Active'));
      });
    }
  });
}
