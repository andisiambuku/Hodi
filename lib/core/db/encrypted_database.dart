import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';

import 'app_database.dart';
import 'key_store.dart';

const dbFileName = 'hodi.sqlite';

/// Result of opening the encrypted database.
class OpenedDatabase {
  const OpenedDatabase(this.db, {required this.recoveredFromLostKey});

  final AppDatabase db;

  /// True when the key was missing but a DB file existed, so the file was
  /// moved aside and a fresh DB created. Unsynced changes in it are lost; the
  /// UI must say so.
  final bool recoveredFromLostKey;
}

/// Opens (or creates) the encrypted database in app-private storage.
///
/// Background isolates (workmanager) must call this same function.
Future<OpenedDatabase> openEncryptedDatabase({
  KeyStore? keyStore,
  File? file,
  void Function(String event)? onTelemetry,
}) async {
  final keys = keyStore ?? SecureKeyStore();
  final dbFile = file ?? await defaultDatabaseFile();

  var recovered = false;
  if (await keys.read() == null && await dbFile.exists()) {
    await moveAside(dbFile);
    // Non-PII event name only.
    onTelemetry?.call('db_key_missing_recovered');
    recovered = true;
  }
  final hexKey = await keys.readOrCreate();

  final db = AppDatabase(
    NativeDatabase.createInBackground(
      dbFile,
      setup: (raw) => configureCipher(raw, hexKey),
    ),
  );
  // Force the connection open now so a wrong key fails here, not mid-query.
  await db.customSelect('SELECT count(*) FROM sqlite_master').get();
  return OpenedDatabase(db, recoveredFromLostKey: recovered);
}

Future<File> defaultDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, dbFileName));
}

/// Renames an unreadable DB (and its -wal/-shm siblings) out of the way.
Future<void> moveAside(File dbFile) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${dbFile.path}$suffix');
    if (await f.exists()) await f.rename('${dbFile.path}$suffix.lost-$stamp');
  }
}

/// Signing out: the DB file and the key go together.
Future<void> destroyLocalData({KeyStore? keyStore, File? file}) async {
  final dbFile = file ?? await defaultDatabaseFile();
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${dbFile.path}$suffix');
    if (await f.exists()) await f.delete();
  }
  await (keyStore ?? SecureKeyStore()).delete();
}

/// Connection setup. The key pragma must be the first statement.
void configureCipher(CommonDatabase db, String hexKey) {
  db.execute('PRAGMA key = "x\'$hexKey\'";');
  ensureCipherLoaded(db.select('PRAGMA cipher_version;'));
  db.execute('PRAGMA foreign_keys = ON;');
}

/// Plain SQLite silently ignores `PRAGMA key` and returns no rows for
/// `cipher_version`. Refuse to run unencrypted.
void ensureCipherLoaded(Iterable<Object?> cipherVersionRows) {
  if (cipherVersionRows.isEmpty) {
    throw StateError('SQLCipher not loaded: database would be unencrypted');
  }
}
