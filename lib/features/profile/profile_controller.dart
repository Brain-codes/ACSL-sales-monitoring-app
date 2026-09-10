import 'package:get/get.dart';
import 'package:stove_transaction/core/model/profile_model.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class ProfileController extends GetxController {
  final _session = Get.find<SessionManager>();
  final _supabase = Get.find<SupabaseService>();
  final isLoading = false.obs;

  /// Set when the last profile refresh did not land. The stored profile is
  /// still shown; this says it could not be confirmed against the server.
  final refreshError = ''.obs;


  @override
  void onInit() {
    super.onInit();
    refreshProfile();
  }

  ProfileModel? get profile => _session.getUserProfileModel();
  String get displayName => _session.userFullName ?? _session.userName ?? 'User';
  String get email => _session.userEmail ?? '';
  String get role => _session.role ?? '';
  String get orgName => _session.organizationName ?? '';
  String get orgBranch => _session.organizationBranch ?? '';
  String get orgState => _session.organizationState ?? '';

  String get roleLabel {
    switch (role) {
      case 'acsl_agent': return 'ACSL Agent';
      case 'partner_agent': return 'Partner Agent';
      case 'admin': return 'Admin';
      default: return role;
    }
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }

  DataRefreshService? get _refreshService {
    try { return Get.find<DataRefreshService>(); } catch (_) { return null; }
  }

  bool get isRefreshing => _refreshService?.isRefreshing.value ?? false;

  DateTime? get lastRefreshedAt => _refreshService?.lastRefreshedAt.value;

  String get lastSyncedLabel {
    final dt = lastRefreshedAt;
    if (dt == null) return 'Never synced';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }

  /// Manual (user-initiated) resync. Always loud: shows the progress pill and
  /// returns whether the fetch actually brought new data, so the caller can
  /// say "synchronized" vs "already up to date".
  Future<bool> refreshData() async {
    final changed = await _refreshService?.refreshAll(silent: false) ?? false;
    update();
    return changed;
  }

  int get pendingCount {
    try { return Get.find<OfflineQueueService>().pendingCount.value; } catch (_) { return 0; }
  }

  /// Re-reads the signed-in user's profile from the server.
  ///
  /// M15: a failure here used to be invisible — the call returned, nothing was
  /// saved, and the screen went on showing the stored profile as though it had
  /// just been confirmed. The user had no way to tell a fresh profile from a
  /// stale one, which matters when a role or an organisation has changed.
  ///
  /// The stored profile is deliberately KEPT on failure — this app is
  /// offline-first, and a dead network must never blank someone's identity.
  /// [refreshError] says the refresh did not land; it does not mean the profile
  /// on screen is unusable.
  Future<void> refreshProfile() async {
    isLoading.value = true;
    refreshError.value = '';
    try {
      final resp = await _supabase.callEdgeFunction(
        'manage-profile',
        body: {},
        method: 'GET',
      );

      if (!resp.success) {
        refreshError.value = resp.message.isEmpty
            ? 'Could not refresh your profile.'
            : resp.message;
        return;
      }

      final data = resp.data is Map ? resp.data as Map : null;
      final profileData = data?['data'] as Map?;
      final profileMap = profileData?['profile'] as Map?;

      if (profileMap == null) {
        refreshError.value =
            'Could not refresh your profile — the server sent no profile.';
        return;
      }

      final merged = Map<String, dynamic>.from(profileMap);
      final orgMap = profileData?['organization'] as Map?;
      if (orgMap != null) {
        merged['organization'] = Map<String, dynamic>.from(orgMap);
      }
      _session.saveUserProfile(merged);
    } catch (e) {
      refreshError.value = 'Could not refresh your profile — $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> hasPendingSales() async {
    return pendingCount > 0;
  }

  Future<void> logout() async {
    await Get.find<AuthService>().signOut();
  }
}
