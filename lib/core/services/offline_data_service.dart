import 'dart:io';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/form/services/form_services.dart';
import 'package:stove_transaction/admin/sales/services/sale_api_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class OfflineDataService extends GetxService {
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final SaleApiService _saleApiService = SaleApiService(SupabaseService());
  final FormService _formService = FormService(SupabaseService());
  final GetStorage _storage = GetStorage();
  final Logger _logger = Logger();

  // Observable variables
  final RxBool isDownloading = false.obs;
  final RxString downloadStatus = ''.obs;
  final RxInt downloadProgress = 0.obs;
  final RxBool isOfflineMode = false.obs;
  final Rx<DateTime?> lastOfflineDataDownload = Rx<DateTime?>(null);

  // Storage keys
  static const String _offlineDataKey = 'offline_bulk_data';
  static const String _lastDownloadKey = 'last_offline_download';
  static const String _offlineModeKey = 'offline_mode_enabled';

  @override
  void onInit() {
    super.onInit();
    _loadOfflineModeState();
    _loadLastDownloadTime();
  }

  /// Load offline mode state from storage
  void _loadOfflineModeState() {
    try {
      final isEnabled = _storage.read(_offlineModeKey) ?? false;
      isOfflineMode.value = isEnabled;
      _logger.d('Loaded offline mode state: ${isOfflineMode.value}');
    } catch (e) {
      _logger.e('Error loading offline mode state: $e');
      isOfflineMode.value = false;
    }
  }

  /// Load last download time from storage
  void _loadLastDownloadTime() {
    try {
      final lastDownloadString = _storage.read(_lastDownloadKey);
      if (lastDownloadString != null) {
        lastOfflineDataDownload.value = DateTime.tryParse(lastDownloadString);
        _logger
            .d('Last offline data download: ${lastOfflineDataDownload.value}');
      }
    } catch (e) {
      _logger.e('Error loading last download time: $e');
    }
  }

  /// Toggle offline mode
  Future<void> toggleOfflineMode() async {
    try {
      isOfflineMode.value = !isOfflineMode.value;
      await _storage.write(_offlineModeKey, isOfflineMode.value);

      _logger.d('Offline mode toggled to: ${isOfflineMode.value}');

      if (isOfflineMode.value) {
        showSuccessToast(
          title: 'Offline Mode Enabled',
          message: 'You can now work offline with downloaded data',
        );
      } else {
        showInfoToast(
          title: 'Offline Mode Disabled',
          message: 'App will now use live data when online',
        );
      }
    } catch (e) {
      _logger.e('Error toggling offline mode: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to toggle offline mode',
      );
    }
  }

  /// Download all necessary data for offline use
  Future<bool> downloadOfflineData() async {
    if (isDownloading.value) {
      _logger.w('Download already in progress');
      return false;
    }

    // Check internet connectivity
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      showErrorToast(
        title: 'No Internet Connection',
        message: 'Internet connection required to download offline data',
      );
      return false;
    }

    isDownloading.value = true;
    downloadProgress.value = 0;
    downloadStatus.value = 'Starting offline data download...';

    try {
      _logger.d('Starting offline data download...');

      // Step 1: Download Stove IDs from Supabase
      downloadStatus.value = 'Downloading stove IDs...';
      downloadProgress.value = 10;
      await _downloadStoveIdsData();

      // Step 2: Download Sales data
      downloadStatus.value = 'Downloading sales data...';
      downloadProgress.value = 30;
      await _downloadSalesData();

      // Step 3: Download User/Organization data
      downloadStatus.value = 'Downloading user data...';
      downloadProgress.value = 50;
      await _downloadUserData();

      // Step 4: Download States and LGAs data (if applicable)
      downloadStatus.value = 'Downloading location data...';
      downloadProgress.value = 70;
      await _downloadLocationData();

      // Step 5: Download any other required reference data
      downloadStatus.value = 'Finalizing download...';
      downloadProgress.value = 90;
      await _finalizeOfflineData();

      // Complete
      downloadProgress.value = 100;
      downloadStatus.value = 'Download completed successfully!';

      // Save download timestamp
      final now = DateTime.now();
      lastOfflineDataDownload.value = now;
      await _storage.write(_lastDownloadKey, now.toIso8601String());

      showSuccessToast(
        title: 'Download Complete',
        message:
            'All data downloaded for offline use. You can now enable offline mode.',
      );

      _logger.d('Offline data download completed successfully');
      return true;
    } catch (e) {
      _logger.e('Error downloading offline data: $e');
      downloadStatus.value = 'Download failed: $e';

      showErrorToast(
        title: 'Download Failed',
        message: 'Failed to download offline data: $e',
      );
      return false;
    } finally {
      isDownloading.value = false;
    }
  }

  /// Download Stove IDs data from Supabase for offline use
  Future<void> _downloadStoveIdsData() async {
    try {
      _logger.d('Downloading stove IDs from Supabase...');
      final organizationId = _sessionManager.organizationId;
      if (organizationId == null) {
        throw Exception('Organization ID not found');
      }
      final response =
          await _formService.fetchStoveIds(organizationId: organizationId);
      if (response.success && response.data != null) {
        final offlineData = await _getOfflineData();
        // Store as a list of maps for offline use
        offlineData['stoveIdsData'] =
            response.data!.map((e) => e.toJson()).toList();
        await _saveOfflineData(offlineData);
        _logger
            .d('Downloaded ${response.data!.length} stove IDs from Supabase');
      } else {
        throw Exception('Failed to fetch stove IDs: ${response.message}');
      }
    } catch (e) {
      _logger.e('Error downloading stove IDs: $e');
      throw Exception('Failed to download stove IDs: $e');
    }
  }

  /// Download Sales data
  Future<void> _downloadSalesData() async {
    try {
      _logger.d('Downloading sales data...');

      // Download sales for the user's organization
      final organizationId = _sessionManager.organizationId;
      if (organizationId == null) {
        throw Exception('Organization ID not found');
      }

      // Fetch sales data using the API service
      // Note: This might need to be updated based on your actual API structure
      final response = await _saleApiService.fetchSales(
        page: 1,
        limit: 1000, // Download a large number of records
      );

      if (response.success && response.data != null) {
        final offlineData = await _getOfflineData();
        offlineData['salesData'] =
            response.data!.sales; // Access sales from PaginatedSales
        await _saveOfflineData(offlineData);

        _logger.d('Downloaded ${response.data!.sales.length} sales records');
      } else {
        throw Exception('Failed to fetch sales data: ${response.message}');
      }
    } catch (e) {
      _logger.e('Error downloading sales data: $e');
      throw Exception('Failed to download sales data: $e');
    }
  }

  /// Download User/Organization data
  Future<void> _downloadUserData() async {
    try {
      _logger.d('Downloading user/organization data...');

      // Store current session data
      final offlineData = await _getOfflineData();
      offlineData['userData'] = {
        'userId': _sessionManager.userId,
        'role': _sessionManager.role,
        'organizationId': _sessionManager.organizationId,
        'organizationName': _sessionManager.organizationName,
        'userEmail': _sessionManager.userEmail,
        'userFullName': _sessionManager.userFullName,
        // Add any other user data that might be needed offline
      };
      await _saveOfflineData(offlineData);

      _logger.d('Downloaded user/organization data');
    } catch (e) {
      _logger.e('Error downloading user data: $e');
      throw Exception('Failed to download user data: $e');
    }
  }

  /// Download location data (States and LGAs)
  Future<void> _downloadLocationData() async {
    try {
      _logger.d('Downloading location data...');

      // For now, we'll store basic location data
      // This can be expanded to fetch from an API if you have one
      final locationData = {
        'states': [
          'Abia',
          'Adamawa',
          'Akwa Ibom',
          'Anambra',
          'Bauchi',
          'Bayelsa',
          'Benue',
          'Borno',
          'Cross River',
          'Delta',
          'Ebonyi',
          'Edo',
          'Ekiti',
          'Enugu',
          'FCT',
          'Gombe',
          'Imo',
          'Jigawa',
          'Kaduna',
          'Kano',
          'Katsina',
          'Kebbi',
          'Kogi',
          'Kwara',
          'Lagos',
          'Nasarawa',
          'Niger',
          'Ogun',
          'Ondo',
          'Osun',
          'Oyo',
          'Plateau',
          'Rivers',
          'Sokoto',
          'Taraba',
          'Yobe',
          'Zamfara'
        ],
        'defaultLGAs': [
          'Select LGA', 'LGA 1', 'LGA 2',
          'LGA 3' // This should be updated with actual LGA data
        ]
      };

      final offlineData = await _getOfflineData();
      offlineData['locationData'] = locationData;
      await _saveOfflineData(offlineData);

      _logger.d('Downloaded location data');
    } catch (e) {
      _logger.e('Error downloading location data: $e');
      throw Exception('Failed to download location data: $e');
    }
  }

  /// Finalize offline data setup
  Future<void> _finalizeOfflineData() async {
    try {
      _logger.d('Finalizing offline data...');

      final offlineData = await _getOfflineData();
      offlineData['downloadMetadata'] = {
        'downloadedAt': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'dataComplete': true,
      };
      await _saveOfflineData(offlineData);

      _logger.d('Offline data finalized');
    } catch (e) {
      _logger.e('Error finalizing offline data: $e');
      throw Exception('Failed to finalize offline data: $e');
    }
  }

  /// Get offline data from storage
  Future<Map<String, dynamic>> _getOfflineData() async {
    try {
      final data = _storage.read(_offlineDataKey);
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e) {
      _logger.e('Error getting offline data: $e');
      return {};
    }
  }

  /// Save offline data to storage
  Future<void> _saveOfflineData(Map<String, dynamic> data) async {
    try {
      await _storage.write(_offlineDataKey, data);
    } catch (e) {
      _logger.e('Error saving offline data: $e');
      throw Exception('Failed to save offline data: $e');
    }
  }

  /// Get stove IDs data for offline use
  List<Map<String, dynamic>> getOfflineStoveIdsData() {
    try {
      final offlineData = _storage.read(_offlineDataKey);
      if (offlineData != null && offlineData is Map) {
        final stoveIdsData = offlineData['stoveIdsData'];
        if (stoveIdsData != null && stoveIdsData is List) {
          return List<Map<String, dynamic>>.from(stoveIdsData);
        }
      }
      return [];
    } catch (e) {
      _logger.e('Error getting offline stove IDs data: $e');
      return [];
    }
  }

  /// Get sales data for offline use
  List<Map<String, dynamic>> getOfflineSalesData() {
    try {
      final offlineData = _storage.read(_offlineDataKey);
      if (offlineData != null && offlineData is Map) {
        final salesData = offlineData['salesData'];
        if (salesData != null && salesData is List) {
          return List<Map<String, dynamic>>.from(salesData);
        }
      }
      return [];
    } catch (e) {
      _logger.e('Error getting offline sales data: $e');
      return [];
    }
  }

  /// Get location data for offline use
  Map<String, dynamic> getOfflineLocationData() {
    try {
      final offlineData = _storage.read(_offlineDataKey);
      if (offlineData != null && offlineData is Map) {
        final locationData = offlineData['locationData'];
        if (locationData != null && locationData is Map) {
          return Map<String, dynamic>.from(locationData);
        }
      }
      return {};
    } catch (e) {
      _logger.e('Error getting offline location data: $e');
      return {};
    }
  }

  /// Check if offline data is available and recent
  bool hasValidOfflineData() {
    try {
      final offlineData = _storage.read(_offlineDataKey);
      if (offlineData == null || offlineData is! Map) {
        return false;
      }

      final metadata = offlineData['downloadMetadata'];
      if (metadata == null || metadata is! Map) {
        return false;
      }

      final downloadedAtString = metadata['downloadedAt'];
      if (downloadedAtString == null) {
        return false;
      }

      final downloadedAt = DateTime.tryParse(downloadedAtString);
      if (downloadedAt == null) {
        return false;
      }

      // Check if data is less than 7 days old
      final daysSinceDownload = DateTime.now().difference(downloadedAt).inDays;
      return daysSinceDownload < 7;
    } catch (e) {
      _logger.e('Error checking offline data validity: $e');
      return false;
    }
  }

  /// Clear all offline bulk data
  Future<void> clearOfflineData() async {
    try {
      await _storage.remove(_offlineDataKey);
      await _storage.remove(_lastDownloadKey);
      lastOfflineDataDownload.value = null;

      showSuccessToast(
        title: 'Data Cleared',
        message: 'Offline data has been cleared',
      );

      _logger.d('Offline bulk data cleared');
    } catch (e) {
      _logger.e('Error clearing offline data: $e');
      showErrorToast(
        title: 'Error',
        message: 'Failed to clear offline data',
      );
    }
  }

  /// Check internet connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get formatted last download time
  String getLastDownloadTimeFormatted() {
    if (lastOfflineDataDownload.value == null) {
      return 'Never';
    }

    final lastDownload = lastOfflineDataDownload.value!;
    final now = DateTime.now();
    final difference = now.difference(lastDownload);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
