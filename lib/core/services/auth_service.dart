import 'package:get/get.dart';

class AuthService extends GetxService {
  Future<bool> login(String email, String password) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    // Simulate successful login for specific credentials, otherwise fail
    if (email == 'admin@example.com' && password == 'Admin@1234') {
      return true;
    } else if (email == 'agent@example.com' && password == 'Admin@1234') {
      return true;
    } {
      return false;
    }
  }

  // You can add other authentication methods here like logout, register, etc.
}
