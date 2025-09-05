import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stove_transaction/core/model/profile_model.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';

class SessionManager extends GetxService {
  final GetStorage _box = GetStorage();

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

  // Basic getters
  String? get userId => _box.read(_userIdKey);
  String? get role => _box.read(_roleKey);
  String? get token => _box.read(_tokenKey);
  String? get userName => _box.read(_userNameKey);
  String? get supabaseSession => _box.read(_supabaseSessionKey);
  String? get timeLoggedIn => _box.read(_timeLoggedInKey);

  bool get isAdmin => role == 'admin';
  bool get isAgent => role == 'agent';

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
    return org?['name']?.toString();
  }

  String? get partnerEmail {
    final org = getOrganization();
    return org?['partner_email']?.toString();
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
  }

  void saveUserProfile(Map<String, dynamic> profile) {
    _box.write(_userProfileKey, profile);

    // Extract and save organization data if present
    if (profile['organization'] != null) {
      _box.write(_organizationKey, profile['organization']);
    }
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

  /// Check if user is authenticated (has valid session)
  bool get isAuthenticated {
    return userId != null && token != null && isSessionValid();
  }

  void logout() {
    _box.remove(_userIdKey);
    _box.remove(_roleKey);
    _box.remove(_tokenKey);
    _box.remove(_supabaseSessionKey);
    _box.remove(_timeLoggedInKey);
    _box.remove(_userProfileKey);
    _box.remove(_organizationKey);
  }

  /// Logout and clear all offline data
  void logoutAndClearOfflineData() {
    // Clear session data
    logout();

    // Clear offline data through service
    try {
      final offlineStorage = Get.find<OfflineStorageService>();
      offlineStorage.clearAllOfflineData();
    } catch (e) {
      // If offline storage service is not available, just continue with logout
    }
  }
}
