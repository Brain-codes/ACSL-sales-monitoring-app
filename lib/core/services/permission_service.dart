import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// Outcome of an in-context camera permission check.
enum CameraPermissionResult {
  granted,

  /// Declined this time — asking again later is still allowed.
  denied,

  /// Blocked for good; only the system settings screen can undo it.
  permanentlyDenied,
}

/// Asks for every RUNTIME permission the app needs in one batch at launch,
/// instead of interrupting an agent halfway through recording a sale.
///
/// Only two permissions actually prompt on Android:
///   * camera   — stove photo capture
///   * location — GPS coordinates attached to each sale
///
/// INTERNET / ACCESS_NETWORK_STATE are *install-time* ("normal") permissions:
/// Android grants them at install and there is no dialog to show, so they are
/// deliberately absent here. Gallery picking also needs nothing — image_picker
/// goes through the system photo picker, which carries its own grant.
class PermissionService extends GetxService {
  final Logger _logger = Logger();
  final GetStorage _box = GetStorage();

  /// Bumping the suffix re-prompts everyone (e.g. if a new permission is added).
  static const _askedKey = 'startup_permissions_asked_v1';

  /// The permissions we request up front, in prompt order.
  static const _startupPermissions = <Permission>[
    Permission.camera,
    Permission.locationWhenInUse,
  ];

  /// Whether the startup batch has already been shown once on this device.
  bool get hasAsked => _box.read<bool>(_askedKey) ?? false;

  /// True when every startup permission is already usable — lets callers skip
  /// the rationale UI entirely.
  Future<bool> allGranted() async {
    for (final p in _startupPermissions) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  /// Requests the whole batch. Safe to call more than once: it no-ops after the
  /// first run so we never nag on every launch — Android also permanently
  /// denies a permission the user dismisses twice, so repeat prompting actively
  /// hurts.
  ///
  /// [force] bypasses the once-only guard for an explicit user action such as a
  /// "grant permissions" button in settings.
  Future<Map<Permission, PermissionStatus>> requestStartupPermissions({
    bool force = false,
  }) async {
    if (hasAsked && !force) return {};
    try {
      // permission_handler shows these one after another, so the user accepts
      // everything in a single uninterrupted run at launch.
      final results = await _startupPermissions.request();
      _box.write(_askedKey, true);
      results.forEach((permission, status) {
        _logger.i('Permission $permission → $status');
      });
      return results;
    } catch (e, st) {
      // A permission plugin failure must never block app startup.
      _logger.w('Startup permission request failed: $e',
          error: e, stackTrace: st);
      return {};
    }
  }

  /// Makes sure the camera is usable RIGHT NOW, at the moment the user tapped
  /// "take photo".
  ///
  /// The startup batch is only an optimisation — if the agent tapped "Don't
  /// allow" there (easy to do on a prompt that appears before they've used the
  /// app), the camera button would otherwise be permanently dead while gallery
  /// upload kept working. This re-asks in context, which is exactly where people
  /// do grant it.
  ///
  /// Returns a [CameraPermissionResult] so the caller can tell "user declined"
  /// apart from "blocked in Settings" and message accordingly.
  Future<CameraPermissionResult> ensureCamera() async {
    try {
      var status = await Permission.camera.status;
      if (status.isGranted || status.isLimited) {
        return CameraPermissionResult.granted;
      }
      if (status.isPermanentlyDenied) {
        return CameraPermissionResult.permanentlyDenied;
      }
      status = await Permission.camera.request();
      if (status.isGranted || status.isLimited) {
        return CameraPermissionResult.granted;
      }
      return status.isPermanentlyDenied
          ? CameraPermissionResult.permanentlyDenied
          : CameraPermissionResult.denied;
    } catch (e) {
      // If the permission plugin itself misbehaves, don't block the capture —
      // let image_picker try and surface its own error.
      _logger.w('Camera permission check failed: $e');
      return CameraPermissionResult.granted;
    }
  }

  /// True if any startup permission is permanently denied, meaning the only way
  /// back is the system settings screen.
  Future<bool> anyPermanentlyDenied() async {
    for (final p in _startupPermissions) {
      if (await p.isPermanentlyDenied) return true;
    }
    return false;
  }

  /// Opens the OS settings page so a user who previously hit "Don't allow" can
  /// still recover without reinstalling.
  Future<bool> openSettings() => openAppSettings();
}
