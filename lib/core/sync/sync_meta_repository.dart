import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

class SyncMetaRepository {
  SyncMetaRepository(this._db);

  final AppDatabase _db;

  static const _cursorKey = 'pull_cursor';
  static const _deviceIdKey = 'device_id';
  static const _deviceNameKey = 'device_name';

  Future<String?> _get(String key) async {
    final row = await (_db.select(
      _db.syncMeta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _set(String key, String value) => _db
      .into(_db.syncMeta)
      .insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));

  /// Generic small settings (onboarding flags and the like). Never patient data.
  Future<String?> readValue(String key) => _get(key);

  Future<void> writeValue(String key, String value) => _set(key, value);

  Future<String?> readCursor() => _get(_cursorKey);

  Future<void> writeCursor(String cursor) => _set(_cursorKey, cursor);

  /// Stable per install; used as the HLC node id and to skip our own echoes.
  Future<String> deviceId() async {
    final existing = await _get(_deviceIdKey);
    if (existing != null) return existing;
    final created = const Uuid().v4().substring(0, 8);
    await _set(_deviceIdKey, created);
    return created;
  }

  /// What other devices call this one ("Clinic Tablet 2"); null if unset.
  Future<String?> readDeviceName() => _get(_deviceNameKey);

  Future<void> writeDeviceName(String name) => _set(_deviceNameKey, name);
}
