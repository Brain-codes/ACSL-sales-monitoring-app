import 'package:get/get.dart';
import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';
import 'package:stove_transaction/admin/sub_accounts/services/sales_agent_api_service.dart';

class ManageSalesAgentsController extends GetxController {
  var isLoading = true.obs;
  var salesAgents = <SalesAgent>[].obs;
  final SalesAgentApiService _apiService = SalesAgentApiService();

  @override
  void onInit() {
    super.onInit();
    fetchSalesAgents();
  }

  void fetchSalesAgents() async {
    try {
      isLoading(true);
      var agents = await _apiService.fetchSalesAgents();
      salesAgents.assignAll(agents);
    } finally {
      isLoading(false);
    }
  }
}
