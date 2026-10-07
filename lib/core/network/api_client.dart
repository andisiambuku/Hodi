import '../db/enums.dart';

/// The server, as the app sees it. The real Dio client replaces
/// `FakeApiClient` once the API exists.
abstract class ApiClient {
  /// `GET /health`. True only if the server answered 200. Never throws:
  /// any failure means "not reachable".
  Future<bool> health();

  /// `POST /sync/push`. Each item's [PushItem.id] is the idempotency key:
  /// replaying an id must return the original result, never apply twice.
  ///
  /// Throws [ApiException] if the request as a whole failed. Per-entry
  /// validation failures come back as [PushStatus.rejected] results.
  Future<List<PushResult>> push(
    List<PushItem> items, {
    required String deviceId,
    required String source,
  });

  /// `GET /sync/changes?since=cursor`. Omits changes made by [deviceId].
  Future<ChangesPage> changes({String? since, required String deviceId});
}

class PushItem {
  const PushItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final ChangeOp op;

  /// `{"fields": {name: {"v": ..., "hlc": ...}}, "hlc": ...}`
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

enum PushStatus { acked, rejected }

class PushResult {
  const PushResult({
    required this.outboxId,
    required this.status,
    this.serverVersion = 0,
    this.error,
  });

  final String outboxId;
  final PushStatus status;
  final int serverVersion;

  /// Plain-language reason when rejected.
  final String? error;
}

class RemoteField {
  const RemoteField(this.value, this.hlc);

  final Object? value;
  final String hlc;
}

class RemoteChange {
  const RemoteChange({
    required this.cursor,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.fields,
    required this.serverVersion,
    required this.source,
  });

  /// Opaque position of this change in the server's log.
  final String cursor;
  final String entityType;
  final String entityId;
  final ChangeOp op;
  final Map<String, RemoteField> fields;
  final int serverVersion;

  /// Device that made the change, e.g. "Clinic Tablet 2".
  final String source;
}

class ChangesPage {
  const ChangesPage({required this.changes, required this.cursor});

  final List<RemoteChange> changes;
  final String cursor;
}

sealed class ApiException implements Exception {
  const ApiException();
}

/// No answer: offline, timeout, connection dropped.
class NetworkException extends ApiException {
  const NetworkException([this.detail = '']);

  final String detail;

  @override
  String toString() => 'NetworkException';
}

/// The server answered with a 5xx.
class ServerException extends ApiException {
  const ServerException([this.statusCode = 500]);

  final int statusCode;

  @override
  String toString() => 'ServerException($statusCode)';
}
