import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends GetxService {
  final SupabaseClient _client = Supabase.instance.client;
  final SessionManager _sessionManager = Get.find<SessionManager>();
  final Logger _logger = Logger();

  /// Initialize the auth service and check current session status
  @override
  void onInit() {
    super.onInit();
    _setupAuthListener();
  }

  /// Setup auth state listener to handle session changes
  void _setupAuthListener() {
    _client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      _logger.d('Auth state changed: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session != null) {
            _sessionManager.saveSupabaseSession(session);
            _logger.d('User signed in, session saved');
          }
          break;
        case AuthChangeEvent.signedOut:
          _sessionManager.logout();
          _logger.d('User signed out, session cleared');
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (session != null) {
            _sessionManager.saveSupabaseSession(session);
            _sessionManager.setToken(session.accessToken);
            _logger.d('Token refreshed, session updated');
          }
          break;
        default:
          break;
      }
    });
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    final currentSession = _client.auth.currentSession;
    final savedSession = _sessionManager.getSupabaseSession();

    return currentSession != null ||
        (savedSession != null && _sessionManager.isSessionValid());
  }

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Ensure user is authenticated, redirect to login if not
  Future<bool> ensureAuthenticated() async {
    if (!isAuthenticated) {
      // Try to restore session first
      final restored = await _restoreSessionIfNeeded();
      if (!restored) {
        _redirectToLogin();
        return false;
      }
    }
    return true;
  }

  /// Try to restore session from storage
  Future<bool> _restoreSessionIfNeeded() async {
    try {
      final savedSession = _sessionManager.getSupabaseSession();

      if (savedSession == null) {
        _logger.d('No saved session to restore');
        return false;
      }

      // Check if session is still valid
      if (_sessionManager.isSessionValid()) {
        _logger
            .d('Session is still valid, current session should be available');
        // The session should already be available in Supabase client
        return _client.auth.currentSession != null;
      } else if (savedSession.refreshToken != null) {
        _logger.d('Session expired, attempting refresh...');
        try {
          final response =
              await _client.auth.refreshSession(savedSession.refreshToken!);
          return response.session != null;
        } catch (e) {
          _logger.e('Failed to refresh session: $e');
          _sessionManager.logout();
          return false;
        }
      }
    } catch (e) {
      _logger.e('Error restoring session: $e');
    }

    return false;
  }

  /// Redirect to login screen
  void _redirectToLogin() {
    _logger.d('Redirecting to login...');
    Get.offAllNamed(AppRoutes.LOGIN);
  }

  /// Manual refresh token
  Future<bool> refreshToken() async {
    try {
      final savedSession = _sessionManager.getSupabaseSession();

      if (savedSession?.refreshToken == null ||
          savedSession!.refreshToken!.isEmpty) {
        _logger.e('No refresh token available');
        _sessionManager.logout();
        return false;
      }

      _logger.d('Attempting manual token refresh...');
      final response =
          await _client.auth.refreshSession(savedSession.refreshToken!);

      if (response.session != null &&
          response.session!.accessToken.isNotEmpty) {
        _sessionManager.saveSupabaseSession(response.session);
        _sessionManager.setToken(response.session!.accessToken);
        _logger.d('Token refreshed successfully');
        return true;
      } else {
        _logger.e('Token refresh failed: No valid session returned');
        _sessionManager.logout();
        return false;
      }
    } catch (e) {
      _logger.e('Token refresh failed: $e');

      // Handle specific refresh token errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('refresh_token_not_found') ||
          errorString.contains('invalid refresh token') ||
          errorString.contains('refresh token not found') ||
          errorString.contains('session_not_found')) {
        _logger.e('Invalid refresh token, clearing session');
        _sessionManager.logout();
      }

      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      _logger.e('Error during logout: $e');
    } finally {
      _sessionManager.logoutAndClearOfflineData();
      Get.offAllNamed(AppRoutes.LOGIN);
    }
  }

  Future<bool> login(String email, String password) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    // Simulate successful login for specific credentials, otherwise fail
    if (email == 'admin@example.com' && password == 'Admin@1234') {
      return true;
    } else if (email == 'agent@example.com' && password == 'Admin@1234') {
      return true;
    } else {
      return false;
    }
  }

  // You can add other authentication methods here like logout, register, etc.
}
