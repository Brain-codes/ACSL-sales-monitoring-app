import 'package:get/get.dart';
import 'package:stove_transaction/core/utils/app_date.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/features/dashboard/models/dashboard_model.dart';
import 'dashboard_service.dart';

class DashboardController extends GetxController {
  final _service = DashboardService();
  final _cache = Get.find<LocalCacheService>();
  final _connectivity = Get.find<ConnectivityService>();

  final isLoading = false.obs;
  // M11: the working year is the Lagos year, not the handset's.
  final selectedYear = lagosToday().year.obs;
  final Rxn<DashboardStats> stats = Rxn<DashboardStats>();

  /// True when the figures on screen came from the local cache (offline or a
  /// failed live fetch) rather than a fresh server response. Drives the
  /// grayscale "offline data" treatment on the KPI cards.
  final isStale = false.obs;

  /// When the currently-shown cached stats were last refreshed from the server.
  final Rxn<DateTime> lastUpdated = Rxn<DateTime>();

  final _naira = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  String fmt(double v) => _naira.format(v);

  /// Human label for when the cached stats were last refreshed.
  String get lastUpdatedLabel {
    final t = lastUpdated.value;
    if (t == null) return 'Offline data';
    return 'Offline data · last updated ${DateFormat('d MMM, h:mm a').format(t)}';
  }

  List<int> get years {
    final now = lagosToday().year;
    return List.generate(now - 2023, (i) => now - i);
  }

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }

  Future<void> fetchStats() async {
    final year = selectedYear.value;
    isLoading.value = true;

    // Offline: skip the network entirely and render from cache (marked stale).
    if (!_connectivity.isOnline.value) {
      _loadFromCache(year);
      isLoading.value = false;
      return;
    }

    try {
      final resp = await _service.getStats(year: year);
      if (resp.success && resp.data != null) {
        final raw = resp.data as Map;
        final payload = raw.containsKey('data') && raw['data'] is Map
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : Map<String, dynamic>.from(raw);
        stats.value = DashboardStats.fromJson(payload);
        isStale.value = false;
        lastUpdated.value = DateTime.now();
        _cache.saveDashboardStats(year, payload); // freshen the offline copy
      } else {
        // Live fetch failed — fall back to whatever we cached last.
        _loadFromCache(year);
      }
    } catch (_) {
      _loadFromCache(year);
    } finally {
      isLoading.value = false;
    }
  }

  /// Loads the cached stats for [year] and flags them as stale (offline data).
  /// Leaves the current stats untouched if nothing is cached.
  void _loadFromCache(int year) {
    final cached = _cache.getDashboardStats(year);
    if (cached != null) {
      stats.value = DashboardStats.fromJson(cached);
      isStale.value = true;
      lastUpdated.value = _cache.dashboardStatsSavedAt(year);
    }
  }
}
