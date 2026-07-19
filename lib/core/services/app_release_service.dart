import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/constants/app_config.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';

/// Current hard-coded app version — keep in sync with pubspec.yaml version field.
const String kAppVersion = '1.0.12';

class AppReleaseInfo {
  final String version;
  final String releaseNotes;
  final String baseUrl;
  final String apkPath;
  final bool isForceUpdate;

  const AppReleaseInfo({
    required this.version,
    required this.releaseNotes,
    required this.baseUrl,
    required this.apkPath,
    required this.isForceUpdate,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) => AppReleaseInfo(
        version: json['version']?.toString() ?? kAppVersion,
        releaseNotes: json['release_notes']?.toString() ?? '',
        baseUrl: json['base_url']?.toString() ?? '',
        apkPath: json['apk_path']?.toString() ?? '/downloads/sales-monitoring-app.apk',
        isForceUpdate: json['is_force_update'] == true,
      );

  /// Direct APK download URL — opens in the browser and triggers a download.
  String get downloadUrl {
    final path = apkPath.startsWith('/') ? apkPath : '/$apkPath';
    return '$baseUrl$path';
  }
}

class AppReleaseService extends GetxService {
  final Logger _logger = Logger();

  final Rx<AppReleaseInfo?> latestRelease = Rx(null);
  final RxBool hasUpdate = false.obs;
  final RxBool isForceUpdate = false.obs;

  @override
  void onInit() {
    super.onInit();
    _fetchAndCheck();
    // Retry once connectivity returns, so an offline launch still learns about
    // updates without the startup timeout noise. Stops re-checking after an
    // update is found.
    try {
      final connectivity = Get.find<ConnectivityService>();
      ever<bool>(connectivity.isOnline, (online) {
        if (online && !hasUpdate.value) _fetchAndCheck();
      });
    } catch (_) {}
  }

  Future<void> _fetchAndCheck() async {
    // Skip entirely when offline: the request would just burn the 10s timeout
    // and log a scary stack trace. It re-runs automatically on reconnect.
    try {
      if (!Get.find<ConnectivityService>().isOnline.value) return;
    } catch (_) {}
    try {
      final uri = Uri.parse('${AppConfig.acslSupabaseURL}/functions/v1/manage-app-release');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final info = AppReleaseInfo.fromJson(data);
      latestRelease.value = info;

      if (_isNewer(info.version, kAppVersion)) {
        hasUpdate.value = true;
        isForceUpdate.value = info.isForceUpdate;
        _logger.i('Update available: ${info.version} (current: $kAppVersion)');
      }
    } catch (e) {
      _logger.w('App release check failed: $e');
    }
  }

  /// Returns true if [remote] version is strictly newer than [current].
  bool _isNewer(String remote, String current) {
    try {
      final r = _parse(remote);
      final c = _parse(current);
      for (int i = 0; i < 3; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) { parts.add(0); }
    return parts;
  }
}
