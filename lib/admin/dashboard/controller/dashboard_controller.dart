import 'package:get/get.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';

class DashboardController extends GetxController {
  final OfflineStorageService _offlineStorage =
      Get.find<OfflineStorageService>();

  var totalSales = 0.obs;
  var pendingSync = 0.obs;
  var salesAgents = 0.obs;
  var stovesWithLandmark = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize with mock data
    refreshDashboardData();
  }

  Future<void> refreshDashboardData() async {
    // Get real offline data statistics
    final offlineStats = _offlineStorage.getSyncStatistics();

    // Simulate fetching data
    totalSales.value = 1250;
    pendingSync.value =
        offlineStats['totalUnsynced'] ?? 0; // Real offline data count
    salesAgents.value = 25;
    stovesWithLandmark.value = 300;

    await Future.delayed(const Duration(seconds: 1));
  }
}
