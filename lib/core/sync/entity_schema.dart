import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/enums.dart';

enum FieldType { text, integer, real, dateTime }

class FieldSpec {
  const FieldSpec(
    this.column,
    this.type, {
    this.label = '',
    this.unit = '',
    this.clinical = false,
  });

  final String column;
  final FieldType type;

  /// Plain-language name used in conflict copy, e.g. "temperature".
  final String label;
  final String unit;

  /// Vitals, medications, test results and diagnoses must never be silently
  /// overwritten, even when the resolution is automatic.
  final bool clinical;
}

/// What the sync layer needs to know about one kind of record.
class EntitySchema {
  const EntitySchema({
    required this.type,
    required this.noun,
    required this.table,
    required this.tableName,
    required this.fields,
    required this.createOnly,
    required this.subjectSql,
    required this.labelPrefix,
  });

  final String type;

  /// "visit", "vitals": used in copy.
  final String noun;
  final TableInfo<Table, dynamic> table;
  final String tableName;

  /// Editable, mergeable fields (by wire name).
  final Map<String, FieldSpec> fields;

  /// Set once on creation (foreign keys); never part of a conflict.
  final Map<String, FieldSpec> createOnly;

  /// `SELECT <name> ... WHERE id = ?` giving the patient the record is about.
  final String subjectSql;

  /// Outbox label prefix: "Visit", "Vitals".
  final String labelPrefix;

  Map<String, FieldSpec> get allFields => {...createOnly, ...fields};
}

Map<String, EntitySchema> buildSchemas(AppDatabase db) => {
  'visit': EntitySchema(
    type: 'visit',
    noun: 'visit',
    table: db.visits,
    tableName: 'visits',
    labelPrefix: 'Visit',
    fields: const {
      'patientName': FieldSpec(
        'patient_name',
        FieldType.text,
        label: 'patient name',
      ),
      'visitType': FieldSpec('visit_type', FieldType.text, label: 'visit type'),
      'scheduledAt': FieldSpec(
        'scheduled_at',
        FieldType.dateTime,
        label: 'visit time',
      ),
      'completedAt': FieldSpec(
        'completed_at',
        FieldType.dateTime,
        label: 'completion time',
      ),
    },
    createOnly: const {'patientId': FieldSpec('patient_id', FieldType.text)},
    subjectSql: 'SELECT patient_name AS n FROM visits WHERE id = ?',
  ),
  'vitals': EntitySchema(
    type: 'vitals',
    noun: 'vitals',
    table: db.vitals,
    tableName: 'vitals',
    labelPrefix: 'Vitals',
    fields: const {
      'temperatureC': FieldSpec(
        'temperature_c',
        FieldType.real,
        label: 'temperature',
        unit: '°C',
        clinical: true,
      ),
      'systolic': FieldSpec(
        'systolic',
        FieldType.integer,
        label: 'systolic blood pressure',
        unit: 'mmHg',
        clinical: true,
      ),
      'diastolic': FieldSpec(
        'diastolic',
        FieldType.integer,
        label: 'diastolic blood pressure',
        unit: 'mmHg',
        clinical: true,
      ),
    },
    createOnly: const {'visitId': FieldSpec('visit_id', FieldType.text)},
    subjectSql:
        'SELECT v.patient_name AS n FROM vitals t JOIN visits v ON v.id = t.visit_id WHERE t.id = ?',
  ),
  'patient': EntitySchema(
    type: 'patient',
    noun: 'patient record',
    table: db.patients,
    tableName: 'patients',
    labelPrefix: 'Patient',
    fields: const {
      'fullName': FieldSpec('full_name', FieldType.text, label: 'name'),
      'householdId': FieldSpec(
        'household_id',
        FieldType.text,
        label: 'household',
      ),
    },
    createOnly: const {},
    subjectSql: 'SELECT full_name AS n FROM patients WHERE id = ?',
  ),
  'household': EntitySchema(
    type: 'household',
    noun: 'household',
    table: db.households,
    tableName: 'households',
    labelPrefix: 'Household',
    fields: const {
      'headName': FieldSpec(
        'head_name',
        FieldType.text,
        label: 'head of household',
      ),
      'location': FieldSpec('location', FieldType.text, label: 'location'),
    },
    createOnly: const {},
    subjectSql: 'SELECT head_name AS n FROM households WHERE id = ?',
  ),
};

/// Raw, whitelisted-SQL access to any synced table by entity type, so the
/// resolver and the conflict actions don't repeat themselves per table.
/// Table and column names come only from [EntitySchema], never from input.
class EntityStore {
  EntityStore(this._db) : schemas = buildSchemas(_db);

  final AppDatabase _db;
  final Map<String, EntitySchema> schemas;

  EntitySchema? schemaFor(String type) => schemas[type];

  /// JSON-friendly current values by wire field name, plus `deleted`; null if
  /// the row doesn't exist.
  Future<LocalRow?> read(String type, String id) async {
    final s = schemas[type]!;
    final rows = await _db
        .customSelect(
          'SELECT * FROM ${s.tableName} WHERE id = ?',
          variables: [Variable.withString(id)],
          readsFrom: {s.table},
        )
        .get();
    if (rows.isEmpty) return null;
    final d = rows.first.data;
    return LocalRow(
      values: {
        for (final e in s.allFields.entries)
          e.key: fromSql(e.value, d[e.value.column]),
      },
      deleted: (d['deleted'] as int? ?? 0) == 1,
      serverVersion: d['server_version'] as int? ?? 0,
      hlc: d['hlc'] as String? ?? '',
    );
  }

  Future<String> subject(String type, String id) async {
    final s = schemas[type]!;
    final rows = await _db
        .customSelect(
          s.subjectSql,
          variables: [Variable.withString(id)],
          readsFrom: {s.table},
        )
        .get();
    return rows.isEmpty
        ? 'this patient'
        : (rows.first.data['n'] as String? ?? 'this patient');
  }

  Future<void> insert(
    String type,
    String id,
    Map<String, Object?> jsonValues, {
    required String hlc,
    required int serverVersion,
    SyncState state = SyncState.synced,
  }) {
    final s = schemas[type]!;
    final cols = <String>['id', 'hlc', 'server_version', 'sync_state'];
    final vars = <Variable>[
      Variable.withString(id),
      Variable.withString(hlc),
      Variable.withInt(serverVersion),
      Variable.withString(state.name),
    ];
    for (final e in s.allFields.entries) {
      if (!jsonValues.containsKey(e.key)) continue;
      cols.add(e.value.column);
      vars.add(toVariable(e.value, jsonValues[e.key]));
    }
    return _db.customInsert(
      'INSERT INTO ${s.tableName} (${cols.join(',')}) VALUES (${List.filled(cols.length, '?').join(',')})',
      variables: vars,
      updates: {s.table},
    );
  }

  /// Writes the given fields (wire names; unknown names are ignored).
  Future<void> update(
    String type,
    String id,
    Map<String, Object?> jsonValues, {
    String? hlc,
    int? serverVersion,
    SyncState? state,
    bool? deleted,
  }) {
    final s = schemas[type]!;
    final sets = <String>[];
    final vars = <Variable>[];
    for (final e in s.fields.entries) {
      if (!jsonValues.containsKey(e.key)) continue;
      sets.add('${e.value.column} = ?');
      vars.add(toVariable(e.value, jsonValues[e.key]));
    }
    if (hlc != null) {
      sets.add('hlc = ?');
      vars.add(Variable.withString(hlc));
    }
    if (serverVersion != null) {
      sets.add('server_version = ?');
      vars.add(Variable.withInt(serverVersion));
    }
    if (state != null) {
      sets.add('sync_state = ?');
      vars.add(Variable.withString(state.name));
    }
    if (deleted != null) {
      sets.add('deleted = ?');
      vars.add(Variable.withBool(deleted));
    }
    if (sets.isEmpty) return Future.value();
    vars.add(Variable.withString(id));
    return _db.customUpdate(
      'UPDATE ${s.tableName} SET ${sets.join(', ')} WHERE id = ?',
      variables: vars,
      updates: {s.table},
    );
  }

  /// Removes the row (and a visit's vitals).
  Future<void> hardDelete(String type, String id) async {
    final s = schemas[type]!;
    if (type == 'visit') {
      await _db.customUpdate(
        'DELETE FROM vitals WHERE visit_id = ?',
        variables: [Variable.withString(id)],
        updates: {_db.vitals},
      );
    }
    await _db.customUpdate(
      'DELETE FROM ${s.tableName} WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {s.table},
    );
  }

  /// Derives the badge: needs review beats waiting beats synced. Call after
  /// anything that changes the outbox or conflicts for the entity.
  Future<void> refreshState(String type, String id) async {
    final s = schemas[type];
    if (s == null) return;
    final unacked = await _db
        .customSelect(
          'SELECT count(*) AS c FROM outbox WHERE entity_type = ? AND entity_id = ? AND status NOT IN (?, ?)',
          variables: [
            Variable.withString(type),
            Variable.withString(id),
            Variable.withString(OutboxStatus.acked.name),
            Variable.withString(OutboxStatus.failed.name),
          ],
          readsFrom: {_db.outbox},
        )
        .getSingle();
    final failed = await _db
        .customSelect(
          'SELECT count(*) AS c FROM outbox WHERE entity_type = ? AND entity_id = ? AND status = ?',
          variables: [
            Variable.withString(type),
            Variable.withString(id),
            Variable.withString(OutboxStatus.failed.name),
          ],
          readsFrom: {_db.outbox},
        )
        .getSingle();
    final review = await _db
        .customSelect(
          'SELECT count(*) AS c FROM conflicts WHERE entity_type = ? AND entity_id = ? AND resolved = 0 AND kind != ?',
          variables: [
            Variable.withString(type),
            Variable.withString(id),
            Variable.withString(ConflictKind.merged.name),
          ],
          readsFrom: {_db.conflicts},
        )
        .getSingle();

    final state = review.read<int>('c') > 0
        ? SyncState.conflict
        : failed.read<int>('c') > 0
        ? SyncState.failed
        : unacked.read<int>('c') > 0
        ? SyncState.pending
        : SyncState.synced;
    await update(type, id, const {}, state: state);
  }

  // ── value conversion ────────────────────────────────────────────────

  /// SQL → wire JSON. Dates become ISO-8601 UTC strings.
  Object? fromSql(FieldSpec f, Object? v) {
    if (v == null) return null;
    return switch (f.type) {
      FieldType.dateTime => DateTime.fromMillisecondsSinceEpoch(
        (v as int) * 1000,
        isUtc: true,
      ).toIso8601String(),
      FieldType.real => (v as num).toDouble(),
      _ => v,
    };
  }

  Variable toVariable(FieldSpec f, Object? json) {
    if (json == null) return const Variable<Object>(null);
    return switch (f.type) {
      FieldType.text => Variable.withString(json as String),
      FieldType.integer => Variable.withInt((json as num).toInt()),
      FieldType.real => Variable.withReal((json as num).toDouble()),
      FieldType.dateTime => Variable.withInt(
        DateTime.parse(json as String).millisecondsSinceEpoch ~/ 1000,
      ),
    };
  }

  /// Equality that survives JSON round-trips (1 vs 1.0, date formats).
  bool sameValue(FieldSpec f, Object? a, Object? b) {
    if (a == null || b == null) return a == b;
    return switch (f.type) {
      FieldType.dateTime => DateTime.parse(
        a as String,
      ).isAtSameMomentAs(DateTime.parse(b as String)),
      FieldType.real || FieldType.integer => (a as num) == (b as num),
      _ => a == b,
    };
  }

  static String encodeValue(Object? v) => jsonEncode(v);
  static Object? decodeValue(String s) => jsonDecode(s);
  static String newId() => const Uuid().v7();
}

class LocalRow {
  const LocalRow({
    required this.values,
    required this.deleted,
    required this.serverVersion,
    required this.hlc,
  });

  final Map<String, Object?> values;
  final bool deleted;
  final int serverVersion;
  final String hlc;
}
