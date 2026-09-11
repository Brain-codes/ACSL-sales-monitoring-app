import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

/// The running app's version, read from the build at start-up.
///
/// M16: this was a hardcoded constant that somebody had to remember to keep in
/// step with pubspec.yaml by hand. When the two drifted, the update check
/// compared the release against the WRONG current version — either nagging
/// about an update already installed, or missing one entirely.
///
/// [AppReleaseService.init] fills this from package_info_plus, which reads the
/// version the build was actually stamped with. The literal is only a fallback
/// for the moment before init runs.
String kAppVersion = '1.0.17';

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
  final SupabaseService _supabase = Get.find<SupabaseService>();

  /// Reads the running version off the build before anything checks it.
  Future<AppReleaseService> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) kAppVersion = info.version;
      _logger.i('App version: $kAppVersion (build ${info.buildNumber})');
    } catch (e) {
      // Keep the fallback literal rather than failing start-up over a version
      // string. The update check still runs, just against the constant.
      _logger.w('Could not read the app version from the build: $e');
    }
    return this;
  }

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
      // M17: this used to build a URL and call http.get directly, bypassing the
      // app's own edge-function client — so it missed the auth header, the 401
      // refresh-and-retry, and the shared error handling every other call gets.
      // No endpoint should be reached two different ways.
      final resp = await _supabase
          .callEdgeFunction(
            'manage-app-release',
            body: const {},
            method: 'GET',
            requireAuth: false,
          )
          .timeout(const Duration(seconds: 10));

      if (!resp.success || resp.data is! Map) return;

      final data = Map<String, dynamic>.from(resp.data as Map);
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
