import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/db/encrypted_database.dart';
import 'package:hodi/core/db/key_store.dart';
import 'package:sqlite3/sqlite3.dart' as plain;

void main() {
  late Directory dir;
  late File file;
  late InMemoryKeyStore keys;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hodi_db_test');
    file = File('${dir.path}/hodi.sqlite');
    keys = InMemoryKeyStore();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> insertHousehold(OpenedDatabase opened, String head) =>
      opened.db.customInsert(
        'INSERT INTO households (id, hlc, head_name, location) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('h-$head'),
          Variable.withString('hlc'),
          Variable.withString(head),
          Variable.withString('Kinangop'),
        ],
      );

  group('encryption at rest', () {
    test(
      'file is not readable by plain sqlite3 and has no SQLite header',
      () async {
        final opened = await openEncryptedDatabase(keyStore: keys, file: file);
        await insertHousehold(opened, 'Wanjiru');
        await opened.db.close();

        final bytes = await file.readAsBytes();
        expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
        expect(String.fromCharCodes(bytes), isNot(contains('Wanjiru')));

        // Opening without PRAGMA key must fail on first read.
        final raw = plain.sqlite3.open(file.path);
        addTearDown(raw.close);
        expect(
          () => raw.select('SELECT * FROM sqlite_master'),
          throwsA(isA<plain.SqliteException>()),
        );
      },
    );

    test('wrong key cannot read the file', () async {
      final opened = await openEncryptedDatabase(keyStore: keys, file: file);
      await opened.db.close();

      final raw = plain.sqlite3.open(file.path);
      addTearDown(raw.close);
      raw.execute('PRAGMA key = "x\'${'ab' * 32}\'";');
      expect(
        () => raw.select('SELECT * FROM sqlite_master'),
        throwsA(isA<plain.SqliteException>()),
      );
    });

    test('reopening with the stored key reads the data back', () async {
      final first = await openEncryptedDatabase(keyStore: keys, file: file);
      await insertHousehold(first, 'Njeri');
      await first.db.close();

      final second = await openEncryptedDatabase(keyStore: keys, file: file);
      addTearDown(second.db.close);
      expect(second.recoveredFromLostKey, isFalse);
      final rows = await second.db.select(second.db.households).get();
      expect(rows.single.headName, 'Njeri');
    });

    test('SQLCipher is linked in this build', () {
      final db = plain.sqlite3.openInMemory();
      addTearDown(db.close);
      expect(db.select('PRAGMA cipher_version;'), isNotEmpty);
    });

    test('ensureCipherLoaded throws when cipher_version returns nothing', () {
      expect(() => ensureCipherLoaded(const []), throwsStateError);
      expect(() => ensureCipherLoaded(const [1]), returnsNormally);
    });
  });

  group('key lifecycle', () {
    test(
      'key is 32 random bytes, hex-encoded, and stable across opens',
      () async {
        final a = await openEncryptedDatabase(keyStore: keys, file: file);
        await a.db.close();
        final key = keys.value!;
        expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));

        final b = await openEncryptedDatabase(keyStore: keys, file: file);
        await b.db.close();
        expect(keys.value, key);
      },
    );

    test('generated keys differ', () {
      expect(generateDbKey(), isNot(generateDbKey()));
    });

    test(
      'missing key + existing file: moves file aside, starts fresh, flags',
      () async {
        final first = await openEncryptedDatabase(keyStore: keys, file: file);
        await insertHousehold(first, 'Lost');
        await first.db.close();
        final oldKey = keys.value;

        keys.value = null; // app data partially cleared
        final events = <String>[];
        final second = await openEncryptedDatabase(
          keyStore: keys,
          file: file,
          onTelemetry: events.add,
        );
        addTearDown(second.db.close);

        expect(second.recoveredFromLostKey, isTrue);
        expect(events, ['db_key_missing_recovered']);
        expect(events.join(), isNot(contains('Lost')));
        expect(keys.value, isNot(oldKey));
        expect(await second.db.select(second.db.households).get(), isEmpty);
        expect(
          dir.listSync().whereType<File>().where(
            (f) => f.path.contains('.lost-'),
          ),
          isNotEmpty,
        );
      },
    );

    test('first launch (no key, no file) is not a recovery', () async {
      final opened = await openEncryptedDatabase(keyStore: keys, file: file);
      addTearDown(opened.db.close);
      expect(opened.recoveredFromLostKey, isFalse);
    });

    test('sign-out deletes the file and the key together', () async {
      final opened = await openEncryptedDatabase(keyStore: keys, file: file);
      await opened.db.close();
      await destroyLocalData(keyStore: keys, file: file);
      expect(await file.exists(), isFalse);
      expect(keys.value, isNull);
    });
  });
}
