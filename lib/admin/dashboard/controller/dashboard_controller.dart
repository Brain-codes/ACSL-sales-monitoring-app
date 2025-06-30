import 'package:get/get.dart';

class DashboardController extends GetxController {
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
    // Simulate fetching data
    totalSales.value = 1250;
    pendingSync.value = 15;
    salesAgents.value = 25;
    stovesWithLandmark.value = 300;
    await Future.delayed(const Duration(seconds: 1));
  }
}
