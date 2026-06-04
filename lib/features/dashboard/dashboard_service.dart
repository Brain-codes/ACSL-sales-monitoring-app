import 'package:get/get.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class DashboardService {
  final _supabase = Get.find<SupabaseService>();

  Future<SupabaseApiResponse<dynamic>> getStats({required int year}) async {
    final role = Get.find<SessionManager>().role;
    // ACSL agents and managers use the agent dashboard; super admin uses the global one
    final functionName = (role == 'acsl_agent' || role == 'acsl_agent_manager')
        ? 'super-admin-agent-dashboard'
        : 'get-dashboard-stats';
    return _supabase.callEdgeFunction(functionName, body: {'year': year});
  }
}
