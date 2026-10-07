import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the SQLCipher key (hex-encoded 32 bytes). The key lives in the
/// platform keystore, never in files, prefs or logs.
abstract class KeyStore {
  static const keyName = 'hodi.db_key';

  /// The stored key, or null if none exists.
  Future<String?> read();

  Future<void> write(String hexKey);

  Future<void> delete();

  /// Returns the existing key, or generates and stores a new one.
  Future<String> readOrCreate() async {
    final existing = await read();
    if (existing != null) return existing;
    final created = generateDbKey();
    await write(created);
    return created;
  }
}

/// 32 bytes from [Random.secure], hex-encoded (64 chars).
String generateDbKey([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class SecureKeyStore extends KeyStore {
  SecureKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // v11 dropped encryptedSharedPreferences; the default backend is
            // AES-GCM with a Keystore-wrapped key. resetOnError:false so a
            // transient storage error can't silently wipe the DB key.
            aOptions: AndroidOptions(resetOnError: false),
            // Readable after first unlock so background sync can open the
            // DB, and never migrated to another device via backup.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: KeyStore.keyName);

  @override
  Future<void> write(String hexKey) =>
      _storage.write(key: KeyStore.keyName, value: hexKey);

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: KeyStore.keyName);
    } catch (_) {
      // A key that can't be unwrapped may not be deletable by name either.
      // Clearing the whole store is the only way out, and this store holds
      // nothing but the DB key.
      await _storage.deleteAll();
    }
  }
}

/// For tests.
class InMemoryKeyStore extends KeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String hexKey) async => value = hexKey;

  @override
  Future<void> delete() async => value = null;
}
