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

  Future<void> refreshData() async {
    await _refreshService?.refreshAll();
    update();
  }

  int get pendingCount {
    try { return Get.find<OfflineQueueService>().pendingCount.value; } catch (_) { return 0; }
  }

  Future<void> refreshProfile() async {
    isLoading.value = true;
    final resp = await _supabase.callEdgeFunction(
      'manage-profile',
      body: {},
      method: 'GET',
    );
    isLoading.value = false;

    if (resp.success && resp.data is Map) {
      final data = resp.data as Map;
      final profileData = data['data'] as Map?;
      if (profileData != null) {
        final profileMap = profileData['profile'] as Map?;
        final orgMap = profileData['organization'] as Map?;
        if (profileMap != null) {
          final merged = Map<String, dynamic>.from(profileMap);
          if (orgMap != null) {
            merged['organization'] = Map<String, dynamic>.from(orgMap);
          }
          _session.saveUserProfile(merged);
        }
      }
    }
  }

  Future<bool> hasPendingSales() async {
    return pendingCount > 0;
  }

  Future<void> logout() async {
    await Get.find<AuthService>().signOut();
  }
}
