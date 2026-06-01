import 'package:get/get.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends GetxService {
  final _session = Get.find<SessionManager>();

  AuthService() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _session.logout();
        Get.offAllNamed(AppRoutes.login);
      }
    });
  }

  bool get isLoggedIn => _session.isAuthenticated;
  String? get role => _session.role;

  String get initialRoute {
    if (!isLoggedIn) return AppRoutes.splash;
    return _isAcslOrAdmin ? AppRoutes.acslHome : AppRoutes.partnerHome;
  }

  bool get _isAcslOrAdmin =>
      _session.isAcslAgent || _session.isAdmin || _session.role == 'acsl_agent';

  Future<void> signOut() async {
    _session.logout();
    await Supabase.instance.client.auth.signOut();
    Get.offAllNamed(AppRoutes.login);
  }
}
