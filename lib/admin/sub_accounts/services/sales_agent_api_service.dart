import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';

class SalesAgentApiService {
  Future<List<SalesAgent>> fetchSalesAgents() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Dummy data
    return [
      SalesAgent(id: '1', name: 'John Doe', location: 'New York'),
      SalesAgent(id: '2', name: 'Jane Smith', location: 'Los Angeles'),
      SalesAgent(id: '3', name: 'Peter Jones', location: 'Chicago'),
    ];
  }
}
