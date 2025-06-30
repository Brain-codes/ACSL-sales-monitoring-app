import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SessionManager extends GetxService {
  Future<SessionManager> init() async {
    return this;
  }

  final _box = GetStorage();

  static const String _userIdKey = 'userId';
  static const String _roleKey = 'role';
  static const String _tokenKey = 'token';
  static const String _userNameKey = 'userName';

  String? get userId => _box.read(_userIdKey);
  String? get role => _box.read(_roleKey);
  String? get token => _box.read(_tokenKey);
  String? get userName => _box.read(_userNameKey);

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

  void setToken(String token) {
    _box.write(_tokenKey, token);
    _box.write(_userNameKey, userName);
  }

  void setRole(String role) {
    _box.write(_roleKey, role);
  }

  void saveUser({
    required String userId,
    required String role,
    required String token,
    required String userName,
  }) {
    _box.write(_userIdKey, userId);
    _box.write(_roleKey, role);
    _box.write(_tokenKey, token);
    _box.write(_userNameKey, userName);
  }

  void logout() {
    _box.remove(_userIdKey);
    _box.remove(_roleKey);
    _box.remove(_tokenKey);
  }
}
