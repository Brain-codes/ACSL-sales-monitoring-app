import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/core/router/app_navigator.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/features/dashboard/dashboard_controller.dart';
import 'package:stove_transaction/features/partners/partners_controller.dart';
import 'package:stove_transaction/features/profile/profile_controller.dart';
import 'package:stove_transaction/features/sales/create/create_sale_controller.dart';
import 'package:stove_transaction/features/sales/list/sales_list_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends GetxService {
  final _session = Get.find<SessionManager>();

  AuthService() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedOut:
          _session.logout();
          goLogin();
          break;
        case AuthChangeEvent.tokenRefreshed:
          // Keep our stored copy of the token/session in lock-step with
          // Supabase's own background refresh so it survives the next cold start.
          if (data.session != null) {
            _session.saveSupabaseSession(data.session);
            _session.setToken(data.session!.accessToken);
          }
          break;
        default:
          break;
      }
    });
  }

  bool get isLoggedIn => _session.isSignedIn;
  String? get role => _session.role;

  /// Called when connectivity returns. Attempts to refresh the access token
  /// using the stored refresh token. Returns true if the session is valid
  /// afterwards. A server-side rejection (revoked/expired refresh token) is the
  /// ONLY condition that forces a sign-out; network/transient errors are
  /// swallowed so the user keeps working offline-first.
  Future<bool> refreshSessionIfPossible() async {
    if (_session.isSessionValid()) return true;
    final saved = _session.getSupabaseSession();
    final refreshToken = saved?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final result =
          await Supabase.instance.client.auth.refreshSession(refreshToken);
      if (result.session != null) {
        _session.saveSupabaseSession(result.session);
        _session.setToken(result.session!.accessToken);
        return true;
      }
      return false;
    } on AuthApiException {
      // Genuine server rejection → the refresh token is dead; force re-auth.
      _session.clearSupabaseSession();
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      _session.logout();
      goLogin();
      return false;
    } catch (_) {
      // Network/transient — keep the stored session and try again later.
      return false;
    }
  }

  /// Soft logout — clears the auth session only, but KEEPS cached/offline data
  /// so it can be reused if the same user logs back in (or after a token
  /// expiry). A different user logging in triggers [wipeAllData] at login time.
  Future<void> signOut() async {
    // 1. Session keys (keeps lastUserId + caches).
    _session.logout();
    // 2. Supabase auth session.
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    // 3. Navigate to login, then drop in-memory feature controllers so they are
    //    recreated fresh for the next login.
    goLogin();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetControllers());
  }

  /// Full wipe — erases EVERYTHING (session, cached data, offline queue) so the
  /// next user starts clean, as if freshly installed. Called from the login
  /// flow when a DIFFERENT user signs in. Does not navigate; the caller
  /// proceeds to save the new session.
  Future<void> wipeAllData() async {
    // Offline queue (SQLite).
    try {
      await Get.find<OfflineQueueService>().clearAll();
    } catch (_) {}
    // All cached data + session keys (GetStorage default box holds both).
    try {
      await GetStorage().erase();
    } catch (_) {}
    // The in-memory phone and buyer-key sets outlive the erase; the keys are
    // scoped to who is signed in, so the next user must not inherit them.
    try {
      Get.find<LocalCacheService>().clear();
    } catch (_) {}
    // Drop stale in-memory feature controllers.
    _resetControllers();
  }

  void _resetControllers() {
    void del(void Function() f) {
      try {
        f();
      } catch (_) {}
    }

    del(() => Get.delete<DashboardController>(force: true));
    del(() => Get.delete<SalesListController>(force: true));
    del(() => Get.delete<PartnersController>(force: true));
    del(() => Get.delete<ProfileController>(force: true));
    del(() => Get.delete<CreateSaleController>(force: true));
  }
}
