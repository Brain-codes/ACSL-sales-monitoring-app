import 'package:get/get.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/features/partners/models/partner_model.dart';

class PartnersController extends GetxController {
  final _supabase = Get.find<SupabaseService>();
  final _session = Get.find<SessionManager>();
  final isLoading = false.obs;
  final RxList<PartnerModel> partners = <PartnerModel>[].obs;
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPartners();
  }

  Future<void> fetchPartners() async {
    final agentId = _session.userId;
    if (agentId == null || agentId.isEmpty) {
      error.value = 'Unable to identify agent. Please log in again.';
      return;
    }

    isLoading.value = true;
    error.value = '';
    final resp = await _supabase.callEdgeFunction(
      'super-admin-agents/$agentId/organizations',
      body: {},
      method: 'GET',
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
