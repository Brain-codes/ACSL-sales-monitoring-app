import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';

const titles = ['mrs'];

Map<String, dynamic> sale(String first, String surname, String phone) => {
      'endUserFirstName': first,
      'endUserSurname': surname,
      'endUserName': '$first $surname',
      'phone': phone,
    };

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  Future<OfflineQueueService> freshQueue() async {
    final db = await factory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 3,
            singleInstance: false, // a fresh in-memory db per test
            onCreate: OfflineQueueService.onCreate,
            onUpgrade: OfflineQueueService.onUpgrade));
    return OfflineQueueService()..attachForTest(db);
  }

  group('pending buyer keys', () {
    test('two rows of one customer → one key; the second would be blocked',
        () async {
      final q = await freshQueue();
      await q.enqueue(payload: sale('Aisha', 'Bello', '08031234567'));
      final keys = await q.getPendingBuyerKeys(titles);
      expect(keys, {'a98b6aac661bef64'});
      // The same customer written differently computes the same key.
      await q.enqueue(payload: sale('Mrs BELLO', 'aisha', '+2348031234567'));
      expect(await q.getPendingBuyerKeys(titles), {'a98b6aac661bef64'});
    });

    test('a family on one number → two keys, one phone', () async {
      final q = await freshQueue();
      await q.enqueue(payload: sale('Aisha', 'Bello', '08031234567'));
      await q.enqueue(payload: sale('Mama', 'Ngozi', '08031234567'));
      expect((await q.getPendingBuyerKeys(titles)).length, 2);
      expect(await q.getPendingEndUserPhones(), {'8031234567'});
    });

    test('the edited row is left out of keys and phones', () async {
      final q = await freshQueue();
      final id = await q.enqueue(payload: sale('Aisha', 'Bello', '08031234567'));
      expect(await q.getPendingBuyerKeys(titles, excludeId: id), isEmpty);
      expect(await q.getPendingEndUserPhones(excludeId: id), isEmpty);
    });
  });

  group('refused rows', () {
    test('markRefused sets the flag; an edit clears it', () async {
      final q = await freshQueue();
      final id = await q.enqueue(payload: sale('Aisha', 'Bello', '08031234567'));
      await q.markRefused(id, 'Not saved');
      var row = await q.getById(id);
      expect(row!['refused'], 1);
      expect(row['error'], 'Not saved');
      expect(q.refusedCount.value, 1);
      expect(q.pendingCount.value, 0);
      // Still listed (the card must not vanish).
      expect((await q.getPending()).length, 1);

      await q.updateQueued(id, payload: sale('Mama', 'Ngozi', '08031234567'));
      row = await q.getById(id);
      expect(row!['refused'], 0);
      expect(row['error'], isNull);
      expect(q.pendingCount.value, 1);
    });

    test('an edit keeps uploaded photo ids', () async {
      final q = await freshQueue();
      final id = await q.enqueue(payload: sale('Aisha', 'Bello', '08031234567'));
      final p = jsonDecode((await q.getById(id))!['payload'] as String)
          as Map<String, dynamic>;
      p[OfflineQueueService.uploadedImagesKey] = {
        'stove_image': {'id': 'img-1', 'sig': 'abc'}
      };
      await q.savePayload(id, p);
      await q.updateQueued(id, payload: sale('Aisha', 'Bello', '08031234567'));
      final after = jsonDecode((await q.getById(id))!['payload'] as String) as Map;
      expect(after[OfflineQueueService.uploadedImagesKey]['stove_image']['id'],
          'img-1');
    });
  });

  test('migration: a version 2 database opens as version 3 with rows intact',
      () async {
    final path = '${(await factory.getDatabasesPath())}/queue_v2_test.db';
    await factory.deleteDatabase(path);
    final v2 = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) => db.execute('''
            CREATE TABLE offline_sales (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              payload TEXT NOT NULL,
              images TEXT,
              created_at TEXT NOT NULL,
              synced INTEGER DEFAULT 0,
              error TEXT,
              needs_resolution INTEGER DEFAULT 0,
              candidates TEXT
            )'''),
        ));
    await v2.insert('offline_sales', {
      'payload': jsonEncode(sale('Aisha', 'Bello', '08031234567')),
      'created_at': DateTime.now().toIso8601String(),
    });
    await v2.close();

    final v3 = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 3,
            onCreate: OfflineQueueService.onCreate,
            onUpgrade: OfflineQueueService.onUpgrade));
    final rows = await v3.query('offline_sales');
    expect(rows.length, 1);
    expect(rows.first['refused'], 0);
    expect(jsonDecode(rows.first['payload'] as String)['endUserSurname'], 'Bello');
    await v3.close();
    await factory.deleteDatabase(path);
  });
}
