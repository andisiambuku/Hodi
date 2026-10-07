import 'package:drift/drift.dart';

import '../enums.dart';

/// Durable queue of local changes. Written in the same transaction as the
/// entity row, so a change can never be saved without being queued.
@DataClassName('OutboxEntry')
@TableIndex(name: 'outbox_status_created', columns: {#status, #createdAt})
class Outbox extends Table {
  /// Also sent as the `Idempotency-Key` header.
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get op => textEnum<ChangeOp>()();

  /// Human copy shown on Pending changes, e.g. "Visit: Grace Njeri".
  TextColumn get label => text()();

  /// JSON: changed fields only, with per-field HLC.
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => textEnum<OutboxStatus>().withDefault(
    Constant(OutboxStatus.queued.name),
  )();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncRun')
@TableIndex(name: 'sync_log_started', columns: {#startedAt})
class SyncLog extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get result => textEnum<SyncRunResult>()();
  IntColumn get sentCount => integer().withDefault(const Constant(0))();
  IntColumn get receivedCount => integer().withDefault(const Constant(0))();

  /// Plain-language copy, e.g. "6 changes sent, 4 received".
  TextColumn get summary => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Conflict')
class Conflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get field => text()();
  TextColumn get fieldLabel => text()();
  TextColumn get subjectName => text()();

  /// JSON-encoded so numbers, strings and null round-trip.
  TextColumn get localValue => text()();
  TextColumn get remoteValue => text()();
  TextColumn get remoteSource => text()();
  TextColumn get unit => text().withDefault(const Constant(''))();
  TextColumn get kind => textEnum<ConflictKind>()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Small key/value store: sync cursor, device id (and device name later).
/// Lives in the encrypted DB so sign-out wipes it with everything else.
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
