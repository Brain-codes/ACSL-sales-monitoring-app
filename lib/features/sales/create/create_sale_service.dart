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

  /// One page of an org's available stoves. `limit` is capped at 500 by the
  /// edge function, so callers must page through with [offset] to get them ALL —
  /// a partner can hold thousands of stoves and a single call silently returns
  /// only the first page.
  Future<SupabaseApiResponse<dynamic>> getAvailableStovesForOrg(
    String orgId, {
    int limit = 500,
    int offset = 0,
  }) {
    return _supabase.callEdgeFunction(
      'get-stove-ids',
      body: {
        'status': 'available',
        'organization_id': orgId,
        'limit': limit,
        'offset': offset,
      },
    );
  }

  Future<SupabaseApiResponse<dynamic>> getPaymentModels() {
    final orgId = Get.find<SessionManager>().organizationId;
    if (orgId == null) {
      return Future.value(SupabaseApiResponse.success([]));
    }
    return _supabase.callEdgeFunction(
      'organization-payment-models/$orgId',
      body: {},
      method: 'GET',
    );
  }

  Future<SupabaseApiResponse<dynamic>> getPaymentModelsForOrg(String orgId) {
    return _supabase.callEdgeFunction(
      'organization-payment-models/$orgId',
      body: {},
      method: 'GET',
    );
  }

  Future<SupabaseApiResponse<dynamic>> getAssignedPartners(String agentId) {
    return _supabase.callEdgeFunction(
      'super-admin-agents/$agentId/organizations',
      body: {},
      method: 'GET',
    );
  }

  /// Super admin: every organization (partner) to choose from.
  Future<SupabaseApiResponse<dynamic>> getAllOrganizations() {
    return _supabase.callEdgeFunction(
      'manage-organizations',
      body: {},
      method: 'GET',
    );
  }

  /// All ACTIVE payment models (decoupled from partners — every partner may use
  /// any active model). See docs/backend/payment-model-decoupling.md.
  Future<SupabaseApiResponse<dynamic>> getAllActivePaymentModels() {
    return _supabase.callEdgeFunction(
      'payment-models',
      body: {},
      method: 'GET',
    );
  }

  /// Agents tied to [orgId] for the "sold on behalf of" picker.
  /// Backed by the new get-organization-agents edge function.
  Future<SupabaseApiResponse<dynamic>> getOrganizationAgents(String orgId) {
    return _supabase.callEdgeFunction(
      'get-organization-agents',
      body: {},
      method: 'GET',
      queryParams: {'organization_id': orgId},
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
