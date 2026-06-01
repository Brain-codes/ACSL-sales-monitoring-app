import 'dart:io';
import 'package:get/get.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class CreateSaleService {
  final _supabase = Get.find<SupabaseService>();

  Future<SupabaseApiResponse<dynamic>> getAvailableStoves() {
    final orgId = Get.find<SessionManager>().organizationId;
    return _supabase.callEdgeFunction(
      'get-stove-ids',
      body: {
        'status': 'available',
        if (orgId != null) 'organization_id': orgId,
      },
    );
  }

  Future<SupabaseApiResponse<dynamic>> getPaymentModels() {
    final orgId = Get.find<SessionManager>().organizationId;
    if (orgId == null) {
      return Future.value(SupabaseApiResponse.success([]));
    }
    // Payment models are org-scoped: GET organization-payment-models/{orgId}
    return _supabase.callEdgeFunction(
      'organization-payment-models/$orgId',
      body: {},
      method: 'GET',
    );
  }

  Future<SupabaseApiResponse<dynamic>> uploadImage(File file, String type) {
    return _supabase.callEdgeFunction(
      'upload-image',
      body: {'file': file, 'type': type},
      isFormData: true,
    );
  }

  Future<SupabaseApiResponse<dynamic>> createSale(Map<String, dynamic> payload) {
    return _supabase.callEdgeFunction('create-sale', body: payload);
  }

  Future<SupabaseApiResponse<dynamic>> getGoogleKeys() {
    return _supabase.callEdgeFunction('get-google-keys', body: {}, method: 'GET');
  }
}
