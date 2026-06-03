import 'package:get/get.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/features/partners/models/partner_model.dart';

enum PartnerSort { name, stovesSold, stovesReceived }

class PartnersController extends GetxController {
  final _supabase = Get.find<SupabaseService>();
  final _session = Get.find<SessionManager>();
  final _cache = Get.find<LocalCacheService>();
  final _connectivity = Get.find<ConnectivityService>();
  final isLoading = false.obs;
  final RxList<PartnerModel> partners = <PartnerModel>[].obs;
  final error = ''.obs;
  final searchQuery = ''.obs;
  final sortBy = PartnerSort.name.obs;

  List<PartnerModel> get displayedPartners {
    var list = partners.where((p) {
      final q = searchQuery.value.toLowerCase();
      if (q.isEmpty) return true;
      return p.partnerName.toLowerCase().contains(q) ||
          p.branch.toLowerCase().contains(q) ||
          p.state.toLowerCase().contains(q);
    }).toList();

    switch (sortBy.value) {
      case PartnerSort.name:
        list.sort((a, b) => a.partnerName.compareTo(b.partnerName));
      case PartnerSort.stovesSold:
        list.sort((a, b) => b.stovesSold.compareTo(a.stovesSold));
      case PartnerSort.stovesReceived:
        list.sort((a, b) => b.stovesAllocated.compareTo(a.stovesAllocated));
    }
    return list;
  }

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

    // Load from cache immediately so offline users see data right away
    final cached = _cache.getAssignedPartners();
    if (cached.isNotEmpty) {
      partners.assignAll(
        cached.map((e) => PartnerModel.fromJson(e)).toList(),
      );
    }

    if (!_connectivity.isOnline.value) {
      if (cached.isEmpty) error.value = 'No internet connection. Sync data while online to view partners offline.';
      return;
    }

    isLoading.value = cached.isEmpty; // only show full spinner on first load
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
      final freshPartners = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _cache.saveAssignedPartners(freshPartners);
      partners.assignAll(freshPartners.map((e) => PartnerModel.fromJson(e)).toList());
    } else if (cached.isEmpty) {
      error.value = resp.message;
    }
  }
}
