import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hodi/core/db/enums.dart';
import 'package:hodi/core/db/key_store.dart';
import 'package:hodi/core/db/encrypted_database.dart';

void main() {
  test('v1 upgrade adds sync_meta and keeps existing data', () async {
    final dir = await Directory.systemTemp.createTemp('hodi_mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/hodi.sqlite');
    final keys = InMemoryKeyStore();

    // Build a current DB, then rewind it to look like schema v1.
    final first = await openEncryptedDatabase(keyStore: keys, file: file);
    await first.db.customStatement(
      "INSERT INTO households (id, hlc, head_name, location) VALUES ('h1','x','Keep me','Kinangop')",
    );
    await first.db.customStatement('DROP TABLE sync_meta');
    await first.db.customStatement(
      'ALTER TABLE patients DROP COLUMN phone_number',
    );
    await first.db.customStatement(
      'ALTER TABLE patients DROP COLUMN account_status',
    );
    await first.db.customStatement('PRAGMA user_version = 1');
    await first.db.close();

    final second = await openEncryptedDatabase(keyStore: keys, file: file);
    addTearDown(second.db.close);
    expect(await second.db.select(second.db.syncMeta).get(), isEmpty);
    final rows = await second.db.select(second.db.households).get();
    expect(rows.single.headName, 'Keep me');
    final v = await second.db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 3);
  });

  test(
    'v2 → v3 upgrade adds phone and status with an active default',
    () async {
      final dir = await Directory.systemTemp.createTemp('hodi_mig3');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/hodi.sqlite');
      final keys = InMemoryKeyStore();

      final first = await openEncryptedDatabase(keyStore: keys, file: file);
      await first.db.customStatement(
        "INSERT INTO patients (id, hlc, full_name) VALUES ('p1','x','Keep me')",
      );
      await first.db.customStatement(
        'ALTER TABLE patients DROP COLUMN phone_number',
      );
      await first.db.customStatement(
        'ALTER TABLE patients DROP COLUMN account_status',
      );
      await first.db.customStatement('PRAGMA user_version = 2');
      await first.db.close();

      final second = await openEncryptedDatabase(keyStore: keys, file: file);
      addTearDown(second.db.close);
      final p = (await second.db.select(second.db.patients).get()).single;
      expect(p.fullName, 'Keep me');
      expect(p.phoneNumber, isNull);
      expect(p.accountStatus, AccountStatus.active);
    },
  );
}
