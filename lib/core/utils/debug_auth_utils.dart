import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugAuthUtils {
  static final Logger _logger = Logger();
  static final SessionManager _sessionManager = Get.find<SessionManager>();
  static final SupabaseClient _client = Supabase.instance.client;

  /// Debug current session state
  static void debugSessionState() {
    _logger.i('=== DEBUG SESSION STATE ===');

    // Check current Supabase session
    final currentSession = _client.auth.currentSession;
    _logger.i(
        'Current Supabase session: ${currentSession != null ? 'EXISTS' : 'NULL'}');
    if (currentSession != null) {
      _logger
          .i('Access token: ${currentSession.accessToken.substring(0, 20)}...');
      _logger.i(
          'Refresh token: ${currentSession.refreshToken?.substring(0, 20) ?? 'NULL'}...');
      _logger.i(
          'Expires at: ${DateTime.fromMillisecondsSinceEpoch((currentSession.expiresAt ?? 0) * 1000)}');
    }

    // Check saved session
    final savedSession = _sessionManager.getSupabaseSession();
    _logger.i('Saved session: ${savedSession != null ? 'EXISTS' : 'NULL'}');
    if (savedSession != null) {
      _logger.i(
          'Saved access token: ${savedSession.accessToken.substring(0, 20)}...');
      _logger.i(
          'Saved refresh token: ${savedSession.refreshToken?.substring(0, 20) ?? 'NULL'}...');
      _logger.i(
          'Saved expires at: ${DateTime.fromMillisecondsSinceEpoch((savedSession.expiresAt ?? 0) * 1000)}');
    }

    // Check session validity
    _logger.i('Session valid: ${_sessionManager.isSessionValid()}');
    _logger.i('Has refresh token: ${_sessionManager.hasValidRefreshToken()}');
    _logger.i('Is authenticated: ${_sessionManager.isAuthenticated}');

    _logger.i('=== END DEBUG SESSION STATE ===');
  }

  /// Test refresh token functionality
  static Future<bool> testRefreshToken() async {
    _logger.i('=== TESTING REFRESH TOKEN ===');

    try {
      final savedSession = _sessionManager.getSupabaseSession();

      if (savedSession?.refreshToken == null) {
        _logger.e('No refresh token available for testing');
        return false;
      }

      _logger.i('Attempting manual refresh...');
      final response =
          await _client.auth.refreshSession(savedSession!.refreshToken!);

      if (response.session != null) {
        _logger.i('✅ Manual refresh successful');
        _logger.i(
            'New access token: ${response.session!.accessToken.substring(0, 20)}...');
        _logger.i(
            'New expires at: ${DateTime.fromMillisecondsSinceEpoch((response.session!.expiresAt ?? 0) * 1000)}');

        // Save the new session
        _sessionManager.saveSupabaseSession(response.session);
        _logger.i('New session saved to storage');

        return true;
      } else {
        _logger.e('❌ Manual refresh failed: No session returned');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Manual refresh failed with error: $e');
      return false;
    } finally {
      _logger.i('=== END TESTING REFRESH TOKEN ===');
    }
  }

  /// Clear all auth data and force logout
  static void clearAllAuthData() {
    _logger.i('=== CLEARING ALL AUTH DATA ===');

    try {
      // Sign out from Supabase
      _client.auth.signOut();
      _logger.i('Signed out from Supabase');
    } catch (e) {
      _logger.e('Error signing out from Supabase: $e');
    }

    // Clear session manager data
    _sessionManager.logout();
    _logger.i('Session manager data cleared');

    _logger.i('=== AUTH DATA CLEARED ===');
  }

  /// Check if current session needs refresh
  static bool needsRefresh() {
    final session = _sessionManager.getSupabaseSession();
    if (session == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = session.expiresAt ?? 0;

    // Check if expires within 5 minutes
    return expiresAt <= (now + 300);
  }

  /// Get session expiry info
  static Map<String, dynamic> getSessionExpiryInfo() {
    final session = _sessionManager.getSupabaseSession();
    if (session == null) {
      return {'hasSession': false, 'message': 'No session available'};
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = session.expiresAt ?? 0;
    final secondsUntilExpiry = expiresAt - now;

    return {
      'hasSession': true,
      'expiresAt': DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
      'secondsUntilExpiry': secondsUntilExpiry,
      'minutesUntilExpiry': (secondsUntilExpiry / 60).round(),
      'isExpired': secondsUntilExpiry <= 0,
      'needsRefresh': needsRefresh(),
    };
  }
}
