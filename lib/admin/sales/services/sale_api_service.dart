import 'package:stove_transaction/admin/sales/model/sale_model.dart';

class SaleApiService {
  Future<List<Sale>> fetchSales() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay
    return [
      Sale(
        id: 'S001',
        product: 'Stove A',
        amount: 1200.00,
        date: DateTime(2023, 1, 15),
        status: 'Completed',
        agentName: 'Agent Alpha',
        userId: 'U001',
      ),
      Sale(
        id: 'S002',
        product: 'Oven B',
        amount: 850.00,
        date: DateTime(2023, 1, 20),
        status: 'Assigned',
        agentName: 'Agent Beta',
        userId: 'U002',
      ),
      Sale(
        id: 'S003',
        product: 'Microwave C',
        amount: 300.00,
        date: DateTime(2023, 2, 1),
        status: 'Pending',
        agentName: 'Agent Gamma',
        userId: 'U003',
      ),
      Sale(
        id: 'S004',
        product: 'Dishwasher D',
        amount: 1500.00,
        date: DateTime(2023, 2, 10),
        status: 'Completed',
        agentName: 'Agent Delta',
        userId: 'U004',
      ),
      Sale(
        id: 'S005',
        product: 'Refrigerator E',
        amount: 2500.00,
        date: DateTime(2023, 2, 25),
        status: 'Assigned',
        agentName: 'Agent Epsilon',
        userId: 'U005',
      ),
    ];
  }
}
