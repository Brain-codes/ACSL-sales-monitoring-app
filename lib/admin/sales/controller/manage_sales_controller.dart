import 'package:get/get.dart';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/admin/sales/services/sale_api_service.dart';

class ManageSalesController extends GetxController {
  var isLoading = true.obs;
  var sales = <Sale>[].obs;
  final SaleApiService _apiService = SaleApiService();

  @override
  void onInit() {
    super.onInit();
    fetchSales();
  }

  void fetchSales() async {
    try {
      isLoading(true);
      var fetchedSales = await _apiService.fetchSales();
      sales.assignAll(fetchedSales);
    } finally {
      isLoading(false);
    }
  }
}
