import 'dart:math';

import '../db/enums.dart';
import '../sync/hlc.dart';
import 'api_client.dart';

class _ServerEntity {
  _ServerEntity();

  final fields = <String, RemoteField>{};
  int version = 0;
  bool deleted = false;
}

/// In-memory server (spec §8): versioning, an HLC, an idempotency table, a
/// change log, tunable latency and failures, and a hook to inject an edit
/// from another device so conflict flows can be demoed.
class FakeApiClient implements ApiClient {
  FakeApiClient({
    this.latency = const Duration(milliseconds: 150),
    this.failureRate = 0,
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random(),
       _clock = HlcClock(nodeId: 'server', now: now);

  Duration latency;

  /// 0..1 chance that any push/changes call fails before reaching the server.
  double failureRate;

  /// Flip to simulate a captive portal / dead server.
  bool healthy = true;

  /// Rejects an item with this message (a 4xx validation failure).
  String? Function(PushItem item)? rejectWhen;

  final Random _random;
  final HlcClock _clock;
  final _epoch = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final _entities = <String, _ServerEntity>{};
  final _processed = <String, PushResult>{};
  final _log = <_Logged>[];
  int _seq = 0;
  final _failQueue = <ApiException>[];
  int _dropResponses = 0;

  /// Number of times a push actually mutated the server (not replays).
  int appliedPushCount = 0;

  /// Next [n] calls to push/changes fail with [error] before doing anything.
  void failNext(int n, [ApiException error = const ServerException()]) {
    for (var i = 0; i < n; i++) {
      _failQueue.add(error);
    }
  }

  /// Next [n] pushes are applied on the server but the response is lost, the
  /// "timeout after the server already processed it" case.
  void dropNextResponses(int n) => _dropResponses += n;

  /// Server-side view of an entity's field, for assertions.
  Object? serverValue(String type, String id, String field) =>
      _entities['$type:$id']?.fields[field]?.value;

  int serverVersion(String type, String id) =>
      _entities['$type:$id']?.version ?? 0;

  bool serverDeleted(String type, String id) =>
      _entities['$type:$id']?.deleted ?? false;

  /// Load pre-existing server state without producing a change-log entry.
  void load(
    String type,
    String id,
    Map<String, Object?> fields, {
    String hlc = '0000000000000-0000-seed',
    int version = 1,
  }) {
    final e = _entities.putIfAbsent('$type:$id', _ServerEntity.new);
    for (final f in fields.entries) {
      e.fields[f.key] = RemoteField(f.value, hlc);
    }
    e.version = version;
  }

  /// An edit made by another device (e.g. "Clinic Tablet 2").
  void injectRemoteEdit({
    required String entityType,
    required String entityId,
    required Map<String, Object?> fields,
    String source = 'Clinic Tablet 2',
    ChangeOp op = ChangeOp.edited,
  }) {
    final hlc = _clock.next();
    _apply(
      entityType,
      entityId,
      op,
      {for (final f in fields.entries) f.key: RemoteField(f.value, hlc)},
      source: source,
      origin: 'remote-device',
    );
  }

  @override
  Future<bool> health() async {
    await Future<void>.delayed(latency);
    return healthy;
  }

  @override
  Future<List<PushResult>> push(
    List<PushItem> items, {
    required String deviceId,
    required String source,
  }) async {
    await Future<void>.delayed(latency);
    _maybeFail();

    final results = <PushResult>[];
    for (final item in items) {
      final replay = _processed[item.id];
      if (replay != null) {
        results.add(replay); // idempotent: same key, same answer, no effect
        continue;
      }
      final reason = rejectWhen?.call(item);
      final PushResult result;
      if (reason != null) {
        result = PushResult(
          outboxId: item.id,
          status: PushStatus.rejected,
          error: reason,
        );
      } else {
        final fields = _fieldsOf(item);
        final version = _apply(
          item.entityType,
          item.entityId,
          item.op,
          fields,
          source: source,
          origin: deviceId,
        );
        appliedPushCount++;
        result = PushResult(
          outboxId: item.id,
          status: PushStatus.acked,
          serverVersion: version,
        );
      }
      _processed[item.id] = result;
      results.add(result);
    }

    if (_dropResponses > 0) {
      _dropResponses--;
      throw const NetworkException('response lost');
    }
    return results;
  }

  @override
  Future<ChangesPage> changes({String? since, required String deviceId}) async {
    await Future<void>.delayed(latency);
    _maybeFail();

    var after = 0;
    if (since != null) {
      final parts = since.split(':');
      // A cursor from another server instance means "start over".
      if (parts.length == 2 && parts[0] == _epoch) {
        after = int.tryParse(parts[1]) ?? 0;
      }
    }
    final visible = _log
        .where((l) => l.seq > after && l.origin != deviceId)
        .map((l) => l.change)
        .toList();
    return ChangesPage(changes: visible, cursor: '$_epoch:$_seq');
  }

  void _maybeFail() {
    if (_failQueue.isNotEmpty) throw _failQueue.removeAt(0);
    if (failureRate > 0 && _random.nextDouble() < failureRate) {
      throw const ServerException();
    }
  }

  Map<String, RemoteField> _fieldsOf(PushItem item) {
    final raw = (item.payload['fields'] as Map?) ?? const {};
    return {
      for (final e in raw.entries)
        e.key as String: RemoteField(
          (e.value as Map)['v'],
          (e.value as Map)['hlc'] as String,
        ),
    };
  }

  int _apply(
    String type,
    String id,
    ChangeOp op,
    Map<String, RemoteField> fields, {
    required String source,
    required String origin,
  }) {
    final e = _entities.putIfAbsent('$type:$id', _ServerEntity.new);
    final applied = <String, RemoteField>{};
    for (final f in fields.entries) {
      final current = e.fields[f.key];
      // Field-level last-writer-wins by HLC.
      if (current == null || f.value.hlc.compareTo(current.hlc) > 0) {
        e.fields[f.key] = f.value;
        applied[f.key] = f.value;
      }
    }
    if (op == ChangeOp.deleted) e.deleted = true;
    if (op == ChangeOp.added) e.deleted = false; // re-created after a delete
    e.version++;
    _seq++;
    _log.add(
      _Logged(
        _seq,
        origin,
        RemoteChange(
          cursor: '$_epoch:$_seq',
          entityType: type,
          entityId: id,
          op: op,
          fields: applied,
          serverVersion: e.version,
          source: source,
        ),
      ),
    );
    return e.version;
  }
}

class _Logged {
  _Logged(this.seq, this.origin, this.change);

  final int seq;
  final String origin;
  final RemoteChange change;
}
