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
    final response = await _supabaseService.selectWhere(
      table: 'profiles',
      column: 'role',
      value: 'agent',
    );
    logger.d(response.message);

    if (response.success) {
      final agents = (response.data as List)
          .map((json) => SalesAgentModel.fromJson(json))
          .toList();
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
