import 'package:get/get.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class DashboardService {
  final _supabase = Get.find<SupabaseService>();

  Future<SupabaseApiResponse<dynamic>> getStats({required int year}) async {
    final role = Get.find<SessionManager>().role;
    // Route to the dashboard the caller's role is allowed to use:
    //  - super_admin            -> global super-admin dashboard
    //  - acsl_agent / manager   -> agent dashboard
    //  - partner / partner_agent-> partner dashboard stats
    final String functionName;
    if (role == 'super_admin') {
      functionName = 'get-super-admin-dashboard';
    } else if (role == 'acsl_agent' || role == 'acsl_agent_manager') {
      functionName = 'super-admin-agent-dashboard';
    } else {
      functionName = 'get-dashboard-stats';
    }
    return _supabase.callEdgeFunction(functionName, body: {'year': year});
  }
}
