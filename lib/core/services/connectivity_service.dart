import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';

class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  StreamSubscription? _subscription;

  Future<ConnectivityService> init() async {
    final result = await Connectivity().checkConnectivity();
    isOnline.value = _connected(result);

    // If already online at startup, trigger sync for any queued offline sales
    if (isOnline.value) {
      _triggerSync();
    }

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = _connected(results);
      final wasOffline = !isOnline.value;
      isOnline.value = online;
      if (online && wasOffline) {
        _triggerSync();
        _triggerDataRefresh();
      }
    });
    return this;
  }

  bool _connected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void _triggerSync() {
    try {
      Get.find<SyncService>().syncPendingSales();
    } catch (_) {}
  }

  void _triggerDataRefresh() {
    try {
      Get.find<DataRefreshService>().refreshAll();
    } catch (_) {}
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
