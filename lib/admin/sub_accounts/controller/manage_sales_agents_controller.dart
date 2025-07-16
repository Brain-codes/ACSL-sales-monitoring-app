import 'package:get/get.dart';
import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';
import 'package:stove_transaction/admin/sub_accounts/services/sales_agent_api_service.dart';
import 'package:stove_transaction/core/services/api_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/shared/ui/toastification_snackbar.dart';

class ManageSalesAgentsController extends GetxController {
  var isLoading = false.obs;
  var salesAgents = <SalesAgentModel>[].obs;
  // final SalesAgentApiService _apiService = SalesAgentApiService(ApiService());
  // final AgentService _agentService = Get.find<AgentService>();
  // Logger logger = Logger();
  final AgentService _agentService = AgentService(SupabaseService());
  @override
  void onInit() {
    super.onInit();
    fetchSalesAgents();
  }

  void fetchSalesAgents() async {
    isLoading.value = true;
    final result = await _agentService.fetchSalesAgents();
    if (result.success) {
      final agents = result.data!;
      salesAgents.value = agents;
      // display agents
    } else {
      showErrorToast(message: result.message);
    }
    isLoading.value = false;
  }
}
