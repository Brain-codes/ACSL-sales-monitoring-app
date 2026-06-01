import 'package:get/get.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class DashboardService {
  final _supabase = Get.find<SupabaseService>();

  Future<SupabaseApiResponse<dynamic>> getStats({required int year}) async {
    final role = Get.find<SessionManager>().role;
    // ACSL agents have their own dedicated dashboard endpoint
    final functionName = role == 'acsl_agent'
        ? 'super-admin-agent-dashboard'
        : 'get-dashboard-stats';
    return _supabase.callEdgeFunction(functionName, body: {'year': year});
  }
}
