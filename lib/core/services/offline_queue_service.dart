import 'dart:convert';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class OfflineQueueService extends GetxService {
  late Database _db;
  final RxInt pendingCount = 0.obs;

  Future<OfflineQueueService> init() async {
    final dbPath = join(await getDatabasesPath(), 'acsl_offline.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            images TEXT,
            created_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            error TEXT
          )
        ''');
      },
    );
    await _refreshCount();
    return this;
  }

  Future<int> enqueue({
    required Map<String, dynamic> payload,
    Map<String, String>? imageBase64Map,
  }) async {
    final id = await _db.insert('offline_sales', {
      'payload': jsonEncode(payload),
      'images': imageBase64Map != null ? jsonEncode(imageBase64Map) : null,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
    await _refreshCount();
    return id;
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final rows = await _db.query(
      'offline_sales',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> markSynced(int id) async {
    await _db.update('offline_sales', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    await _refreshCount();
  }

  Future<void> markError(int id, String error) async {
    await _db.update('offline_sales', {'error': error}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearSynced() async {
    await _db.delete('offline_sales', where: 'synced = 1');
  }

  Future<Set<String>> getPendingStoveIds() async {
    final rows = await _db.query(
      'offline_sales',
      columns: ['payload'],
      where: 'synced = 0',
    );
    final ids = <String>{};
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        final id = payload['stoveId']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      } catch (_) {}
    }
    return ids;
  }

  Future<void> _refreshCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as c FROM offline_sales WHERE synced = 0');
    pendingCount.value = (result.first['c'] as int? ?? 0);
  }
}
