import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:stove_transaction/core/config/env_config.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/sync_service.dart';

/// Network reachability + QUALITY.
///
/// `connectivity_plus` only tells us whether a network *interface* exists
/// (Wi-Fi/mobile), NOT whether the internet is actually usable. On Android
/// (especially bad 2G/edge cells common in the field) the device reports
/// "connected" while requests hang for 20-60s and eventually fail — the app
/// stayed in "online" mode and every action stalled instead of falling back
/// offline.
///
/// This service therefore does an ACTIVE probe: a tiny timed request to
/// Supabase. The outcome maps to three states:
///   * online  — probe succeeded quickly
///   * poor    — interface exists but probe was slow or failed (unusable net)
///   * offline — no network interface at all
///
/// Both `poor` and `offline` drive `isOnline = false`, so every existing
/// offline-first code path (queue sale, read from cache) triggers exactly as
/// before. `isPoorConnection` lets the UI say "very poor internet" instead of
/// a plain "offline" when a dead-slow network is the cause.
enum NetworkQuality { online, poor, offline }

class ConnectivityService extends GetxService {
  /// True only when the internet is actually usable (probe fast + succeeded).
  /// `poor` and `offline` both report false so offline-first logic kicks in.
  final RxBool isOnline = true.obs;

  /// True when there IS a network interface but it's unusable/dead-slow.
  /// Used to show "very poor internet" instead of "offline".
  final RxBool isPoorConnection = false.obs;

  final Rx<NetworkQuality> quality = NetworkQuality.online.obs;

  /// True only once the connection has been usable for several CONSECUTIVE
  /// probes and isn't currently flapping — i.e. genuinely settled, not a
  /// momentary "up" blip in an on/off/on cycle. Use this (not [isOnline]) to
  /// decide whether it's safe to offer a user a switch back to online mode.
  final RxBool isStable = true.obs;

  /// True when the connection has dropped repeatedly inside [_flapWindow].
  /// A network that keeps bouncing is worse than a cleanly dead one: UI that
  /// reacts to every transition thrashes, and long uploads restart forever.
  /// Consumers latch themselves into offline mode when this trips.
  final RxBool isFlapping = false.obs;

  StreamSubscription? _subscription;
  Timer? _pollTimer;
  bool _probing = false;

  /// Consecutive `online` probes required before we call the link "stable".
  /// 3 × [_pollInterval] ≈ 60s of uninterrupted health.
  static const _stableProbes = 3;

  /// Rolling window used to judge flapping, and how many drops trip it.
  static const _flapWindow = Duration(minutes: 2);
  static const _flapDropsToTrip = 2;

  int _consecutiveOnline = 0;
  final List<DateTime> _drops = [];

  /// A probe that finishes under this is treated as a healthy connection.
  /// Above it (but still succeeds) counts as "poor".
  static const _slowThreshold = Duration(seconds: 3);

  /// Hard ceiling: if the probe doesn't complete by this it's "poor/unusable".
  static const _probeTimeout = Duration(seconds: 6);

  /// How often to re-probe while the app is running. Catches the "net silently
  /// went dead-slow" case where no connectivity CHANGE event ever fires.
  static const _pollInterval = Duration(seconds: 20);

  Future<ConnectivityService> init() async {
    await _refreshQuality(triggerReconnect: false);

    if (isOnline.value && _autoSyncOn) {
      _triggerSync();
    }

    // Re-probe whenever the OS reports an interface change...
    _subscription = Connectivity().onConnectivityChanged.listen((_) {
      _refreshQuality();
    });

    // ...and on a steady poll, because a network going dead-slow does NOT
    // emit a connectivity change on Android.
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshQuality());

    return this;
  }

  /// Force an immediate re-check (e.g. user tapped "retry").
  Future<void> recheck() => _refreshQuality();

  bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Runs a timed probe and updates [isOnline]/[isPoorConnection]/[quality].
  Future<void> _refreshQuality({bool triggerReconnect = true}) async {
    if (_probing) return;
    _probing = true;
    try {
      final wasUsable = isOnline.value;
      final results = await Connectivity().checkConnectivity();

      NetworkQuality result;
      if (!_hasInterface(results)) {
        result = NetworkQuality.offline;
      } else {
        result = await _probeInternet();
      }

      quality.value = result;
      isOnline.value = result == NetworkQuality.online;
      isPoorConnection.value = result == NetworkQuality.poor;

      _updateStability(result, wasUsable: wasUsable);

      // Only treat a transition into a *usable* connection as a reconnect.
      if (!wasUsable && isOnline.value && triggerReconnect) {
        _onReconnected();
      }
    } finally {
      _probing = false;
    }
  }

  /// Maintains [isStable] / [isFlapping] from the probe history.
  ///
  /// A drop is only counted when we go from *usable* to unusable, so a link
  /// that is simply down the whole time never registers as "flapping" — that's
  /// a steady offline state, which the UI already handles well.
  void _updateStability(NetworkQuality result, {required bool wasUsable}) {
    final now = DateTime.now();

    if (result == NetworkQuality.online) {
      _consecutiveOnline++;
    } else {
      _consecutiveOnline = 0;
      if (wasUsable) _drops.add(now);
    }

    _drops.removeWhere((t) => now.difference(t) > _flapWindow);
    isFlapping.value = _drops.length >= _flapDropsToTrip;

    // "Stable" demands BOTH a run of healthy probes and no recent drops, so a
    // connection that just came back mid-flap can't masquerade as settled.
    isStable.value = result == NetworkQuality.online &&
        _consecutiveOnline >= _stableProbes &&
        !isFlapping.value;
  }

  /// Tiny timed request to Supabase's health endpoint. Classifies the network
  /// by whether it responds at all and how fast.
  Future<NetworkQuality> _probeInternet() async {
    final base = EnvConfig.supabaseUrl;
    if (base.isEmpty) {
      // No URL to probe — fall back to "interface exists" == online so we don't
      // wrongly force the whole app offline in misconfigured builds.
      return NetworkQuality.online;
    }
    final uri = Uri.parse('$base/auth/v1/health');
    final sw = Stopwatch()..start();
    try {
      final resp = await http.get(uri).timeout(_probeTimeout);
      sw.stop();
      // Any HTTP status (even 4xx) means the round-trip completed — the pipe
      // works. We only care about reachability + speed here, not the body.
      if (resp.statusCode >= 500) return NetworkQuality.poor;
      return sw.elapsed <= _slowThreshold
          ? NetworkQuality.online
          : NetworkQuality.poor;
    } on TimeoutException {
      return NetworkQuality.poor; // interface up but too slow to be usable
    } catch (_) {
      return NetworkQuality.poor; // DNS/socket failure on a live interface
    }
  }

  /// Regained a usable connection: refresh the (possibly expired) access token
  /// FIRST so the subsequent sync/refresh calls carry a valid token, then push
  /// queued sales and pull fresh reference data.
  Future<void> _onReconnected() async {
    try {
      await Get.find<AuthService>().refreshSessionIfPossible();
    } catch (_) {}
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
      // Silent: "your last sync is as good as the last time you were online" —
      // regaining connectivity re-fetches immediately, but in the background
      // with no progress UI (unless nothing has ever been cached).
      Get.find<DataRefreshService>().refreshAll(silent: true);
    } catch (_) {}
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _pollTimer?.cancel();
    super.onClose();
  }
}
