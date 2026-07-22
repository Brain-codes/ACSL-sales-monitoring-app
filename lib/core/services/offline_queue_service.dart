import 'dart:convert';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:stove_transaction/core/utils/phone_utils.dart';

class OfflineQueueService extends GetxService {
  late Database _db;
  final RxInt pendingCount = 0.obs;

  /// Sales that synced-checking flagged as needing manual location resolution
  /// (the typed address didn't confidently match a Google result).
  final RxInt needsResolutionCount = 0.obs;

  Future<OfflineQueueService> init() async {
    final dbPath = join(await getDatabasesPath(), 'acsl_offline.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            images TEXT,
            created_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            error TEXT,
            needs_resolution INTEGER DEFAULT 0,
            candidates TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE offline_sales ADD COLUMN needs_resolution INTEGER DEFAULT 0');
          await db.execute(
              'ALTER TABLE offline_sales ADD COLUMN candidates TEXT');
        }
      },
    );
    await _refreshCounts();
    return this;
  }

  Future<int> enqueue({
    required Map<String, dynamic> payload,
    Map<String, String>? imageBase64Map,
  }) async {
    // Stamp a stable idempotency key ONCE at enqueue time. It rides along on
    // every (re)submission of this sale, so if the server saved a sale but the
    // ack was lost before we could markSynced(), the next retry is deduped
    // server-side instead of creating a duplicate. Never regenerated on edit.
    payload.putIfAbsent('clientRequestId', () => const Uuid().v4());
    final id = await _db.insert('offline_sales', {
      'payload': jsonEncode(payload),
      'images': imageBase64Map != null ? jsonEncode(imageBase64Map) : null,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
    await _refreshCounts();
    return id;
  }

  /// Pending sales that are cleared to sync (not awaiting manual resolution).
  Future<List<Map<String, dynamic>>> getPending() async {
    final rows = await _db.query(
      'offline_sales',
      where: 'synced = 0 AND needs_resolution = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Sales held back for manual location confirmation.
  Future<List<Map<String, dynamic>>> getNeedsResolution() async {
    final rows = await _db.query(
      'offline_sales',
      where: 'synced = 0 AND needs_resolution = 1',
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Fetches a single queued sale row (payload + images + error) by id.
  Future<Map<String, dynamic>?> getById(int id) async {
    final rows = await _db.query('offline_sales', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// Overwrites a queued sale's payload/images (used when the user edits a
  /// pending or failed sale). Clears any prior error/resolution flag so it
  /// re-enters the normal sync path.
  Future<void> updateQueued(
    int id, {
    required Map<String, dynamic> payload,
    Map<String, String>? imageBase64Map,
  }) async {
    // Keep the original idempotency key across edits — editing a pending sale
    // must not turn a retry into a new server record.
    if (payload['clientRequestId'] == null) {
      final existing = await getById(id);
      if (existing != null) {
        try {
          final prev = jsonDecode(existing['payload'] as String) as Map<String, dynamic>;
          if (prev['clientRequestId'] != null) {
            payload['clientRequestId'] = prev['clientRequestId'];
          }
        } catch (_) {}
      }
      payload.putIfAbsent('clientRequestId', () => const Uuid().v4());
    }
    await _db.update(
      'offline_sales',
      {
        'payload': jsonEncode(payload),
        'images': imageBase64Map != null ? jsonEncode(imageBase64Map) : null,
        'error': null,
        'needs_resolution': 0,
        'candidates': null,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _refreshCounts();
  }

  /// Permanently removes a queued sale (the "delete pending record" action).
  /// The buyer's data is lost — the caller must warn the user first.
  Future<void> deleteById(int id) async {
    await _db.delete('offline_sales', where: 'id = ?', whereArgs: [id]);
    await _refreshCounts();
  }

  /// Bulk-removes several queued sales in one transaction (batch "cancel
  /// selected"). Buyer data for those rows is lost — warn the user first.
  /// Returns the number of rows deleted.
  Future<int> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final placeholders = List.filled(ids.length, '?').join(',');
    final count = await _db.delete(
      'offline_sales',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    await _refreshCounts();
    return count;
  }

  /// Removes every not-yet-synced sale ("cancel all pending"). Destructive —
  /// the caller must confirm with the user. Does not touch already-synced rows.
  Future<int> clearPending() async {
    final count = await _db.delete('offline_sales', where: 'synced = 0');
    await _refreshCounts();
    return count;
  }

  Future<void> markSynced(int id) async {
    await _db.update('offline_sales', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    await _refreshCounts();
  }

  Future<void> markError(int id, String error) async {
    await _db.update('offline_sales', {'error': error}, where: 'id = ?', whereArgs: [id]);
  }

  /// Flags a sale as needing manual location resolution and stores the Google
  /// candidate suggestions to show the user.
  Future<void> markNeedsResolution(int id, List<Map<String, dynamic>> candidates) async {
    await _db.update(
      'offline_sales',
      {'needs_resolution': 1, 'candidates': jsonEncode(candidates)},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _refreshCounts();
  }

  /// Applies the user's chosen (or auto-matched) location to a queued sale and
  /// clears the resolution flag so the next sync pushes it.
  Future<void> applyResolution(int id, Map<String, dynamic> resolvedPayload) async {
    await _db.update(
      'offline_sales',
      {
        'payload': jsonEncode(resolvedPayload),
        'needs_resolution': 0,
        'candidates': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _refreshCounts();
  }

  Future<void> clearSynced() async {
    await _db.delete('offline_sales', where: 'synced = 1');
  }

  /// Wipe the entire offline queue (used on logout — full data reset).
  Future<void> clearAll() async {
    await _db.delete('offline_sales');
    await _refreshCounts();
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

  /// Normalized end-user phones of sales still waiting to sync. These aren't on
  /// the server yet, so the cached phone set can't know about them — without
  /// this, two sales created back-to-back offline could share a phone and the
  /// second would only fail later, at sync, with the sale already "made".
  Future<Set<String>> getPendingEndUserPhones() async {
    final rows = await _db.query(
      'offline_sales',
      columns: ['payload'],
      where: 'synced = 0',
    );
    final phones = <String>{};
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        final key = PhoneUtils.normalizePhone(payload['phone']?.toString());
        if (key.isNotEmpty) phones.add(key);
      } catch (_) {}
    }
    return phones;
  }

  Future<void> _refreshCounts() async {
    final pending = await _db.rawQuery(
        'SELECT COUNT(*) as c FROM offline_sales WHERE synced = 0');
    pendingCount.value = (pending.first['c'] as int? ?? 0);
    final needs = await _db.rawQuery(
        'SELECT COUNT(*) as c FROM offline_sales WHERE synced = 0 AND needs_resolution = 1');
    needsResolutionCount.value = (needs.first['c'] as int? ?? 0);
  }
}
