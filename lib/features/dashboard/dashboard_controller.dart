import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/features/dashboard/models/dashboard_model.dart';
import 'dashboard_service.dart';

class DashboardController extends GetxController {
  final _service = DashboardService();

  final isLoading = false.obs;
  final selectedYear = DateTime.now().year.obs;
  final Rxn<DashboardStats> stats = Rxn<DashboardStats>();

  final _naira = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  String fmt(double v) => _naira.format(v);

  List<int> get years {
    final now = DateTime.now().year;
    return List.generate(now - 2023, (i) => now - i);
  }

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }

  Future<void> fetchStats() async {
    isLoading.value = true;
    final resp = await _service.getStats(year: selectedYear.value);
    isLoading.value = false;

    if (resp.success && resp.data != null) {
      stats.value = DashboardStats.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
    }
  }
}
