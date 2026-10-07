import 'package:drift/drift.dart';

import '../enums.dart';

/// Columns every synced entity carries. Ids are device-generated uuid v7.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get syncState =>
      textEnum<SyncState>().withDefault(Constant(SyncState.pending.name))();

  /// Last-modified hybrid logical clock.
  TextColumn get hlc => text()();

  /// 0 until the first server ack.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  /// Soft delete; the row is purged only after the server acks.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Households extends Table with SyncColumns {
  TextColumn get headName => text()();
  TextColumn get location => text()();
}

class Patients extends Table with SyncColumns {
  TextColumn get fullName => text()();
  TextColumn get householdId => text().nullable().references(Households, #id)();
}

@TableIndex(name: 'visits_scheduled_at', columns: {#scheduledAt})
class Visits extends Table with SyncColumns {
  TextColumn get patientId => text().references(Patients, #id)();

  /// Denormalised for list display.
  TextColumn get patientName => text()();
  TextColumn get visitType => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

class Vitals extends Table with SyncColumns {
  TextColumn get visitId => text().references(Visits, #id)();
  RealColumn get temperatureC => real().nullable()();
  IntColumn get systolic => integer().nullable()();
  IntColumn get diastolic => integer().nullable()();
}
