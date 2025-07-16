import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionManager extends GetxService {
  Future<SessionManager> init() async {
    return this;
  }

  final _box = GetStorage();

  static const String _userIdKey = 'userId';
  static const String _roleKey = 'role';
  static const String _tokenKey = 'token';
  static const String _userNameKey = 'userName';
  static const String _supabaseSessionKey = 'supabaseSession';
  static const String _timeLoggedInKey = 'timeLoggedIn';

  String? get userId => _box.read(_userIdKey);
  String? get role => _box.read(_roleKey);
  String? get token => _box.read(_tokenKey);
  String? get userName => _box.read(_userNameKey);
  String? get supabaseSession => _box.read(_supabaseSessionKey);
  String? get timeLoggedIn => _box.read(_timeLoggedInKey);

  bool get isAdmin => role == 'admin';
  bool get isAgent => role == 'agent';

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

  void saveSupabaseSession(Session? sessionData) {
    if (sessionData != null) {
      _box.write(_supabaseSessionKey, sessionData.toJson());
    }
  }

  Session? getSupabaseSession() {
    final data = _box.read(_supabaseSessionKey);
    if (data != null && data is Map<String, dynamic>) {
      return Session.fromJson(data);
    }
    return null;
  }

  void logout() {
    _box.remove(_userIdKey);
    _box.remove(_roleKey);
    _box.remove(_tokenKey);
    _box.remove(_supabaseSessionKey);
    _box.remove(_timeLoggedInKey);
  }
}
