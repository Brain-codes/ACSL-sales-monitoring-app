import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stove_transaction/core/model/profile_model.dart';

class SessionManager extends GetxService {
  final GetStorage _box = GetStorage();

  /// Ticks whenever the signed-in identity changes.
  ///
  /// GetStorage is not reactive, so nothing downstream can tell that a login
  /// or logout happened just by holding this service. Riverpod watches this to
  /// know when to recompute the role and the permissions that follow from it —
  /// without it, permissions resolved once on the splash screen (nobody signed
  /// in, role null) and every user was refused every route afterwards.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _bumpRevision() => revision.value++;

  /// Initialize the SessionManager service
  Future<SessionManager> init() async {
    // Any initialization logic can go here
    return this;
  }

  // Storage keys
  static const String _userIdKey = 'userId';
  static const String _roleKey = 'role';
  static const String _tokenKey = 'token';
  static const String _userNameKey = 'userName';
  static const String _supabaseSessionKey = 'supabaseSession';
  static const String _timeLoggedInKey = 'timeLoggedIn';
  static const String _userProfileKey = 'userProfile';
  static const String _organizationKey = 'organization';

  /// Persists across (soft) logout so the next login can tell whether the same
  /// user or a different user is signing in. Only cleared on a full data wipe.
  static const String _lastUserIdKey = 'lastUserId';

  // Basic getters
  String? get userId => _box.read(_userIdKey);
  String? get role => _box.read(_roleKey);
  String? get token => _box.read(_tokenKey);
  String? get userName => _box.read(_userNameKey);
  String? get supabaseSession => _box.read(_supabaseSessionKey);
  String? get timeLoggedIn => _box.read(_timeLoggedInKey);

  /// Id of the last user who signed in. Survives (soft) logout and token
  /// expiry; only cleared by [wipeAll].
  String? get lastUserId => _box.read(_lastUserIdKey);
  void setLastUserId(String id) => _box.write(_lastUserIdKey, id);

  bool get isAdmin => role == 'admin';
  bool get isAgent => role == 'agent';
  bool get isAcslAgent => role == 'acsl_agent';
  bool get isAcslAgentManager => role == 'acsl_agent_manager';
  bool get isPartnerAgent => role == 'partner_agent';

  /// Sync mode. Offline-first default is MANUAL: sales stay queued until the
  /// user reviews and presses sync. Auto-sync is opt-in (a "flex") — when on,
  /// queued sales upload automatically on reconnect. Persists across sessions;
  /// reset to manual only on a full data wipe. Exposed as an [RxBool] so the
  /// profile toggle and any gating UI react instantly.
  static const String _autoSyncKey = 'autoSyncEnabled';
  late final RxBool autoSyncEnabled = RxBool(_box.read(_autoSyncKey) ?? false);

  void setAutoSync(bool enabled) {
    autoSyncEnabled.value = enabled;
    _box.write(_autoSyncKey, enabled);
  }

  // Stove availability keys
  static const String _stoveAvailableKey = 'totalStoveAvailable';

  /// Store the latest available stove count
  void saveTotalStoveAvailable(int count) {
    _box.write(_stoveAvailableKey, count);
  }

  /// Get the latest available stove count
  int get totalStoveAvailable => _box.read(_stoveAvailableKey) ?? 0;

  /// Centralized checker: returns true if a new sale can be started
  bool canStartNewSale() => totalStoveAvailable > 0;

  // User profile methods
  Map<String, dynamic>? getUserProfile() {
    final profile = _box.read(_userProfileKey);
    if (profile != null && profile is Map<String, dynamic>) {
      return Map<String, dynamic>.from(profile);
    }
    return null;
  }

  /// Get user profile as ProfileModel (strongly typed)
  ProfileModel? getUserProfileModel() {
    final profile = getUserProfile();
    if (profile != null) {
      try {
        return ProfileModel.fromJson(profile);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Organization methods
  Map<String, dynamic>? getOrganization() {
    final org = _box.read(_organizationKey);
    if (org != null && org is Map<String, dynamic>) {
      return Map<String, dynamic>.from(org);
    }
    return null;
  }

  String? get organizationId {
    final org = getOrganization();
    return org?['id']?.toString();
  }

  String? get organizationName {
    final org = getOrganization();
    // Try new field first, fallback to old field for backward compatibility
    return org?['partner_name']?.toString() ?? org?['name']?.toString();
  }

  String? get partnerName {
    final org = getOrganization();
    return org?['partner_name']?.toString();
  }

  String? get organizationBranch {
    final org = getOrganization();
    return org?['branch']?.toString();
  }

  String? get organizationState {
    final org = getOrganization();
    return org?['state']?.toString();
  }

  String? get partnerEmail {
    final org = getOrganization();
    // Try new field first, fallback to old field for backward compatibility
    return org?['email']?.toString() ?? org?['partner_email']?.toString();
  }

  String? get userEmail {
    final profile = getUserProfile();
    return profile?['email']?.toString();
  }

  String? get userFullName {
    final profile = getUserProfile();
    return profile?['full_name']?.toString();
  }

  String? get userPhone {
    final profile = getUserProfile();
    return profile?['phone']?.toString();
  }

  bool get hasChangedPassword {
    final profile = getUserProfile();
    return profile?['has_changed_password'] ?? false;
  }

  Map<String, dynamic>? getUser() {
    if (userId != null && role != null && token != null) {
      return {
        'userId': userId,
        'role': role,
        'token': token,
      };
    }
    return null;
  }

  void setToken(String token, {String? userName}) {
    _box.write(_tokenKey, token);
    if (userName != null) {
      _box.write(_userNameKey, userName);
    }
  }

  void setRole(String role) {
    _box.write(_roleKey, role);
    _bumpRevision();
  }

  void saveUser({
    required String userId,
    required String role,
    required String token,
    required String userName,
    required String timeLoggedIn,
  }) {
    _box.write(_userIdKey, userId);
    _box.write(_roleKey, role);
    _box.write(_tokenKey, token);
    _box.write(_userNameKey, userName);
    _box.write(_timeLoggedInKey, timeLoggedIn);
    _bumpRevision();
  }

  void saveUserProfile(Map<String, dynamic> profile) {
    _box.write(_userProfileKey, profile);

    // Extract and save organization data if present
    if (profile['organization'] != null) {
      _box.write(_organizationKey, profile['organization']);
    }
    // isSignedIn also depends on the profile being present, so this write
    // changes the answer as much as the role write does.
    _bumpRevision();
  }

  void saveCompleteUserData({
    required String userId,
    required String role,
    required String token,
    required String userName,
    required String timeLoggedIn,
    required Map<String, dynamic> profile,
  }) {
    // Save basic user data
    saveUser(
      userId: userId,
      role: role,
      token: token,
      userName: userName,
      timeLoggedIn: timeLoggedIn,
    );

    // Save complete profile with organization
    saveUserProfile(profile);
  }

  void saveSupabaseSession(Session? sessionData) {
    if (sessionData != null) {
      try {
        _box.write(_supabaseSessionKey, sessionData.toJson());
      } catch (e) {
        // If there's an error saving the session, log it
        print('Error saving Supabase session: $e');
      }
    }
  }

  Session? getSupabaseSession() {
    final data = _box.read(_supabaseSessionKey);
    if (data != null && data is Map<String, dynamic>) {
      try {
        return Session.fromJson(data);
      } catch (e) {
        // If there's an error parsing the session, clear it
        print('Error parsing saved session, clearing: $e');
        _box.remove(_supabaseSessionKey);
        return null;
      }
    }
    return null;
  }

  /// Check if the current session is valid (not expired)
  bool isSessionValid() {
    final session = getSupabaseSession();
    if (session == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = session.expiresAt ?? 0;

    // Add a buffer of 5 minutes to account for network delays
    return expiresAt > (now + 300);
  }

  /// Check if refresh token is available and valid
  bool hasValidRefreshToken() {
    final session = getSupabaseSession();
    return session?.refreshToken != null && session!.refreshToken!.isNotEmpty;
  }

  /// Clear only the Supabase session (for refresh token issues)
  void clearSupabaseSession() {
    _box.remove(_supabaseSessionKey);
  }

  /// Check if user is authenticated with a currently-VALID (unexpired) token.
  /// Use this only to decide whether an authenticated API call can be made
  /// right now — NOT for routing/gating the UI.
  bool get isAuthenticated {
    return userId != null && token != null && isSessionValid();
  }

  /// OFFLINE-FIRST sign-in check used for routing/UI gating.
  ///
  /// A user counts as signed in as long as we hold their identity + profile
  /// locally, REGARDLESS of whether the access token has expired. An expired
  /// token only means "can't hit the server right now"; it must never eject a
  /// field user from the app while they're offline. Re-login is forced only
  /// when the server actively rejects the refresh token (see main._restoreSession
  /// and AuthService.refreshSessionIfPossible).
  bool get isSignedIn {
    return userId != null && token != null && getUserProfile() != null;
  }

  void logout() {
    _box.remove(_userIdKey);
    _box.remove(_roleKey);
    _box.remove(_tokenKey);
    _box.remove(_supabaseSessionKey);
    _box.remove(_timeLoggedInKey);
    _box.remove(_userProfileKey);
    _box.remove(_organizationKey);
    _bumpRevision();
  }

  void logoutAndClearOfflineData() {
    logout();
  }
}
