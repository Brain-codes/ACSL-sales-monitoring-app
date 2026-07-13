import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/sync_service.dart';

class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  StreamSubscription? _subscription;

  Future<ConnectivityService> init() async {
    final result = await Connectivity().checkConnectivity();
    isOnline.value = _connected(result);

    // If already online at startup, auto-upload any queued sales — but only
    // when the user has opted into auto-sync. Manual mode is the offline-first
    // default: queued sales wait for an explicit review + sync.
    if (isOnline.value && _autoSyncOn) {
      _triggerSync();
    }

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = _connected(results);
      final wasOffline = !isOnline.value;
      isOnline.value = online;
      if (online && wasOffline) {
        _onReconnected();
      }
    });
    return this;
  }

  bool _connected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Regained connectivity: refresh the (possibly expired) access token FIRST
  /// so the subsequent sync/refresh calls carry a valid token, then push queued
  /// sales and pull fresh reference data.
  Future<void> _onReconnected() async {
    try {
      await Get.find<AuthService>().refreshSessionIfPossible();
    } catch (_) {}
    // Reference-data download always happens; queued SALES only auto-upload in
    // auto-sync mode. In manual mode the user pushes them after reviewing.
    if (_autoSyncOn) _triggerSync();
    _triggerDataRefresh();
  }

  /// Whether queued sales may upload without an explicit user action.
  bool get _autoSyncOn {
    try {
      return Get.find<SessionManager>().autoSyncEnabled.value;
    } catch (_) {
      return false;
    }
  }

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
