import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/dashboard/services/dashboard_service.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class DashboardController extends GetxController {
  final SessionManager _sessionManager = Get.find<SessionManager>();
  // Stove inventory progress fields
  var totalStovesReceived = 0.obs;
  var totalStovesSold = 0.obs;
  var totalStovesAvailable = 0.obs;
  final OfflineStorageService _offlineStorage =
      Get.find<OfflineStorageService>();
  final DashboardService _dashboardService =
      DashboardService(SupabaseService());
  final Logger logger = Logger();

  // Reactive variables for dashboard stats
  var isLoading = false.obs;
  var totalSales = 0.obs;
  var pendingSync = 0.obs;
  var salesAgents = 0.obs;
  var stovesWithLandmark = 0.obs;
  var completedSales = 0.obs;
  var pendingSales = 0.obs;
  var totalSalesAmount = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    refreshDashboardData();
  }

  /// Refresh dashboard data from both offline storage and API
  Future<void> refreshDashboardData() async {
    isLoading.value = true;

    try {
      // Get real offline data statistics
      final offlineStats = _offlineStorage.getSyncStatistics();
      pendingSync.value = offlineStats['totalUnsynced'] ?? 0;

      // Fetch dashboard statistics from API
      final response = await _dashboardService.fetchDashboardStats();

      if (response.success && response.data != null) {
        final stats = response.data!;

        // Update reactive variables with real data
        totalSales.value = stats.totalSales;
        salesAgents.value = stats.salesAgents;
        stovesWithLandmark.value = stats.stovesWithLandmark;
        completedSales.value = stats.completedSales;
        pendingSales.value = stats.pendingSales;
        totalSalesAmount.value = stats.totalSalesAmount;

        // Update stove inventory progress fields (ensure your API returns these fields)
        totalStovesReceived.value = stats.totalStovesReceived ?? 0;
        totalStovesSold.value = stats.totalStovesSold ?? 0;
        totalStovesAvailable.value = stats.totalStovesAvailable ?? 0;

        // Save available stoves to session manager for centralized checker
        _sessionManager.saveTotalStoveAvailable(totalStovesAvailable.value);

        logger.d('Dashboard data refreshed successfully');
      } else {
        logger.e('Failed to fetch dashboard stats: ${response.message}');

        // Check if it's an authentication error
        if (response.message.toLowerCase().contains('session expired') ||
            response.message
                .toLowerCase()
                .contains('authentication required') ||
            response.message.toLowerCase().contains('unauthorized') ||
            response.message.toLowerCase().contains('please login')) {
          // Navigate to login screen for authentication errors
          logger.d('Authentication error detected - navigating to login');
          _handleAuthenticationError();
        } else {
          showInfoToast(
            title: 'Dashboard Error',
            message: 'Failed to load dashboard statistics. Using offline data.',
          );
          // Fallback to default values if API fails
          _setDefaultValues();
        }
      }
    } catch (e) {
      logger.e('Error refreshing dashboard data: $e');

      // Check if it's an authentication-related error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('session expired') ||
          errorString.contains('authentication') ||
          errorString.contains('unauthorized') ||
          errorString.contains('refresh token') ||
          errorString.contains('please login')) {
        // Navigate to login screen for authentication errors
        logger.d(
            'Authentication error in dashboard refresh - navigating to login');
        _handleAuthenticationError();
      } else {
        showErrorToast(
          title: 'Error',
          message: 'An error occurred while loading dashboard data.',
        );
      }

      // Fallback to default values
      _setDefaultValues();
    } finally {
      isLoading.value = false;
    }
  }

  /// Set default values when API fails
  void _setDefaultValues() {
    totalSales.value = 0;
    salesAgents.value = 0;
    stovesWithLandmark.value = 0;
    completedSales.value = 0;
    pendingSales.value = 0;
    totalSalesAmount.value = 0.0;
    totalStovesReceived.value = 0;
    totalStovesSold.value = 0;
    totalStovesAvailable.value = 0;
  }

  /// Handle authentication errors by navigating to login
  void _handleAuthenticationError() {
    // Set default values
    _setDefaultValues();

    // Navigate to login screen
    Get.offAllNamed('/login');
  }
}
