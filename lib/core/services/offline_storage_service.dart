import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';

class OfflineStorageService extends GetxService {
  static const String _salesKey = 'offline_sales';
  static const String _salesEditsKey = 'offline_sales_edits';
  static const String _syncStatusKey = 'sync_status';
  static const String _lastSyncKey = 'last_sync_time';

  final GetStorage _storage = GetStorage();
  final Logger _logger = Logger();

  /// Initialize the offline storage service
  Future<OfflineStorageService> init() async {
    await GetStorage.init();
    _logger.d('OfflineStorageService initialized');
    return this;
  }

  /// Save a new offline sale
  Future<bool> saveOfflineSale(Map<String, dynamic> saleData) async {
    try {
      final offlineSales = getOfflineSales();

      // Add unique offline ID and timestamp
      final offlineId = DateTime.now().millisecondsSinceEpoch.toString();
      saleData['offline_id'] = offlineId;
      saleData['created_offline_at'] = DateTime.now().toIso8601String();
      saleData['sync_status'] = 'pending';
      saleData['is_offline'] = true;

      offlineSales.add(saleData);
      await _storage.write(_salesKey, offlineSales);

      _logger.d('Offline sale saved with ID: $offlineId');
      return true;
    } catch (e) {
      _logger.e('Error saving offline sale: $e');
      return false;
    }
  }

  /// Save an offline sale edit
  Future<bool> saveOfflineSaleEdit(
      String saleId, Map<String, dynamic> editData) async {
    try {
      final offlineEdits = getOfflineSaleEdits();

      // Add edit metadata
      final editId = DateTime.now().millisecondsSinceEpoch.toString();
      editData['edit_id'] = editId;
      editData['sale_id'] = saleId;
      editData['edited_offline_at'] = DateTime.now().toIso8601String();
      editData['sync_status'] = 'pending';
      editData['is_offline_edit'] = true;

      offlineEdits.add(editData);
      await _storage.write(_salesEditsKey, offlineEdits);

      _logger.d('Offline sale edit saved for sale ID: $saleId');
      return true;
    } catch (e) {
      _logger.e('Error saving offline sale edit: $e');
      return false;
    }
  }

  /// Get all offline sales
  List<Map<String, dynamic>> getOfflineSales() {
    try {
      final data = _storage.read(_salesKey);
      if (data != null && data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      _logger.e('Error getting offline sales: $e');
      return [];
    }
  }

  /// Get all offline sale edits
  List<Map<String, dynamic>> getOfflineSaleEdits() {
    try {
      final data = _storage.read(_salesEditsKey);
      if (data != null && data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      _logger.e('Error getting offline sale edits: $e');
      return [];
    }
  }

  /// Get pending offline sales (not synced)
  List<Map<String, dynamic>> getPendingOfflineSales() {
    final offlineSales = getOfflineSales();
    return offlineSales
        .where((sale) => sale['sync_status'] == 'pending')
        .toList();
  }

  /// Get pending offline sale edits (not synced)
  List<Map<String, dynamic>> getPendingOfflineSaleEdits() {
    final offlineEdits = getOfflineSaleEdits();
    return offlineEdits
        .where((edit) => edit['sync_status'] == 'pending')
        .toList();
  }

  /// Get all unsynced records count
  int getUnsyncedRecordsCount() {
    return getPendingOfflineSales().length +
        getPendingOfflineSaleEdits().length;
  }

  /// Mark a sale as synced
  Future<bool> markSaleAsSynced(String offlineId, String? serverId) async {
    try {
      final offlineSales = getOfflineSales();
      final index =
          offlineSales.indexWhere((sale) => sale['offline_id'] == offlineId);

      if (index != -1) {
        offlineSales[index]['sync_status'] = 'synced';
        offlineSales[index]['synced_at'] = DateTime.now().toIso8601String();
        if (serverId != null) {
          offlineSales[index]['server_id'] = serverId;
        }

        await _storage.write(_salesKey, offlineSales);
        _logger.d('Marked sale as synced: $offlineId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error marking sale as synced: $e');
      return false;
    }
  }

  /// Mark a sale edit as synced
  Future<bool> markSaleEditAsSynced(String editId) async {
    try {
      final offlineEdits = getOfflineSaleEdits();
      final index =
          offlineEdits.indexWhere((edit) => edit['edit_id'] == editId);

      if (index != -1) {
        offlineEdits[index]['sync_status'] = 'synced';
        offlineEdits[index]['synced_at'] = DateTime.now().toIso8601String();

        await _storage.write(_salesEditsKey, offlineEdits);
        _logger.d('Marked sale edit as synced: $editId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error marking sale edit as synced: $e');
      return false;
    }
  }

  /// Mark a sale sync as failed
  Future<bool> markSaleAsFailed(String offlineId, String errorMessage) async {
    try {
      final offlineSales = getOfflineSales();
      final index =
          offlineSales.indexWhere((sale) => sale['offline_id'] == offlineId);

      if (index != -1) {
        offlineSales[index]['sync_status'] = 'failed';
        offlineSales[index]['sync_error'] = errorMessage;
        offlineSales[index]['failed_at'] = DateTime.now().toIso8601String();

        await _storage.write(_salesKey, offlineSales);
        _logger.d('Marked sale as failed: $offlineId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error marking sale as failed: $e');
      return false;
    }
  }

  /// Remove synced sales older than specified days
  Future<void> cleanupSyncedSales({int daysOld = 30}) async {
    try {
      final offlineSales = getOfflineSales();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final filteredSales = offlineSales.where((sale) {
        if (sale['sync_status'] != 'synced') return true;

        final syncedAt = DateTime.tryParse(sale['synced_at'] ?? '');
        return syncedAt == null || syncedAt.isAfter(cutoffDate);
      }).toList();

      await _storage.write(_salesKey, filteredSales);

      final offlineEdits = getOfflineSaleEdits();
      final filteredEdits = offlineEdits.where((edit) {
        if (edit['sync_status'] != 'synced') return true;

        final syncedAt = DateTime.tryParse(edit['synced_at'] ?? '');
        return syncedAt == null || syncedAt.isAfter(cutoffDate);
      }).toList();

      await _storage.write(_salesEditsKey, filteredEdits);

      _logger.d('Cleanup completed for records older than $daysOld days');
    } catch (e) {
      _logger.e('Error during cleanup: $e');
    }
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    final lastSyncString = _storage.read(_lastSyncKey);
    if (lastSyncString != null) {
      return DateTime.tryParse(lastSyncString);
    }
    return null;
  }

  /// Update last sync time
  Future<void> updateLastSyncTime() async {
    await _storage.write(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Clear all offline data (use with caution)
  Future<void> clearAllOfflineData() async {
    await _storage.remove(_salesKey);
    await _storage.remove(_salesEditsKey);
    await _storage.remove(_syncStatusKey);
    await _storage.remove(_lastSyncKey);
    _logger.d('All offline data cleared');
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStatistics() {
    final offlineSales = getOfflineSales();
    final offlineEdits = getOfflineSaleEdits();

    final pendingSales =
        offlineSales.where((sale) => sale['sync_status'] == 'pending').length;
    final syncedSales =
        offlineSales.where((sale) => sale['sync_status'] == 'synced').length;
    final failedSales =
        offlineSales.where((sale) => sale['sync_status'] == 'failed').length;

    final pendingEdits =
        offlineEdits.where((edit) => edit['sync_status'] == 'pending').length;
    final syncedEdits =
        offlineEdits.where((edit) => edit['sync_status'] == 'synced').length;
    final failedEdits =
        offlineEdits.where((edit) => edit['sync_status'] == 'failed').length;

    return {
      'sales': {
        'pending': pendingSales,
        'synced': syncedSales,
        'failed': failedSales,
        'total': offlineSales.length,
      },
      'edits': {
        'pending': pendingEdits,
        'synced': syncedEdits,
        'failed': failedEdits,
        'total': offlineEdits.length,
      },
      'lastSync': getLastSyncTime()?.toIso8601String(),
      'totalUnsynced': pendingSales + pendingEdits,
    };
  }

  /// Save offline image file
  Future<String?> saveOfflineImage(File imageFile, String type) async {
    try {
      final directory =
          Directory('${Directory.systemTemp.path}/offline_images');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = File('${directory.path}/$fileName');

      await imageFile.copy(savedFile.path);
      _logger.d('Offline image saved: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      _logger.e('Error saving offline image: $e');
      return null;
    }
  }

  /// Get offline image file
  File? getOfflineImage(String imagePath) {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return file;
      }
      return null;
    } catch (e) {
      _logger.e('Error getting offline image: $e');
      return null;
    }
  }
}
