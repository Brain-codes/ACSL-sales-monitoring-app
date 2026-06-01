import 'package:get/get.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/features/partners/models/partner_model.dart';

class PartnersController extends GetxController {
  final _supabase = Get.find<SupabaseService>();
  final isLoading = false.obs;
  final RxList<PartnerModel> partners = <PartnerModel>[].obs;
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPartners();
  }

  Future<void> fetchPartners() async {
    isLoading.value = true;
    error.value = '';
    final resp = await _supabase.callEdgeFunction(
      'manage-organizations',
      body: {},
      queryParams: {'limit': '100', 'offset': '0'},
    );
    isLoading.value = false;

    if (resp.success && resp.data != null) {
      List raw = [];
      if (resp.data is List) {
        raw = resp.data as List;
      } else if (resp.data is Map) {
        raw = (resp.data as Map)['data'] as List? ?? [];
      }
      partners.assignAll(
        raw.map((e) => PartnerModel.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
    } else {
      error.value = resp.message;
    }
  }
}
