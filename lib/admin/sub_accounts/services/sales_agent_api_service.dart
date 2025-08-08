import 'dart:io';

import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/sub_accounts/model/sales_agent_model.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class AgentService {
  final SupabaseService _supabaseService;
  AgentService(this._supabaseService);
  Logger logger = Logger();

  Future<SupabaseApiResponse<List<SalesAgentModel>>> fetchSalesAgents() async {
    // Use edge function instead of direct table access to avoid RLS policy issues
    final response = await _supabaseService.callEdgeFunction(
      'get-sales-agents',
      body: {},
      requireAuth: true,
    );

    logger.d(response);
    logger.d(response.message);

    if (response.success) {
      // Edge function returns data in the 'data' field of the response
      final responseData = response.data;

      // Check if responseData is a Map with 'data' field (edge function format)
      List<dynamic> agentsList;
      if (responseData is Map<String, dynamic> &&
          responseData.containsKey('data')) {
        agentsList = responseData['data'] as List<dynamic>;
      } else if (responseData is List<dynamic>) {
        // Direct list format
        agentsList = responseData;
      } else {
        logger.e('Unexpected response format: ${responseData.runtimeType}');
        return SupabaseApiResponse.error(
            'Unexpected response format from server');
      }

      final agents =
          agentsList.map((json) => SalesAgentModel.fromJson(json)).toList();
      return SupabaseApiResponse.success(agents);
    } else {
      return SupabaseApiResponse.error(response.message, code: response.code);
    }
  }

  Future<SupabaseApiResponse<dynamic>> createAgent({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final result = await _supabaseService.callEdgeFunction(
      'create-agent-user',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
      },
    );

    return result;
  }

  // New method for form-data uploads
  Future<SupabaseApiResponse<dynamic>> uploadImage({
    required File file,
    required String type,
  }) async {
    final result = await _supabaseService.callEdgeFunction(
      'upload-image',
      body: {
        'type': type,
        'image': file,
      },
      isFormData: true, // Set this flag to true for form-data requests
    );

    return result;
  }
}
