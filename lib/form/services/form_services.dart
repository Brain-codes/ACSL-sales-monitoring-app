import 'package:get/get.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/sales/services/sale_api_service.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/form/model/stove_id_model.dart';
import 'package:stove_transaction/form/model/upload_file_model.dart'; // Import MediaType

class FormService {
  final SessionManager _sessionManager = Get.find<SessionManager>();

  /// Fetch stove totals for an organization and store available count in SessionManager
  Future<int> fetchAndStoreAvailableStoveCount(
      {required String organizationId}) async {
    try {
      final response = await _supabaseService.callEdgeFunction(
        'get-stove-ids',
        body: {
          'organization_id': organizationId,
        },
        requireAuth: true,
      );
      if (response.success && response.data is Map<String, dynamic>) {
        final totals = response.data['totals'];
        if (totals != null && totals is Map<String, dynamic>) {
          final available = totals['total_stove_available'] ?? 0;
          _sessionManager.saveTotalStoveAvailable(available);
          return available is int
              ? available
              : int.tryParse(available.toString()) ?? 0;
        }
      }
      _sessionManager.saveTotalStoveAvailable(0);
      return 0;
    } catch (e) {
      _sessionManager.saveTotalStoveAvailable(0);
      return 0;
    }
  }

  final SupabaseService _supabaseService;
  FormService(this._supabaseService);
  final Dio dio = Dio();
  Logger logger = Logger();

  Future<SupabaseApiResponse<dynamic>> createSales(
      Map<String, dynamic> transactionData) async {
    final response = await _supabaseService.callEdgeFunction(
      'create-sale',
      body: transactionData,
      requireAuth: true,
    );

    if (response.success) {
      return SupabaseApiResponse.success(response.data);
    } else {
      return SupabaseApiResponse.error(response.message, code: response.code);
    }
  }

  Future<SupabaseApiResponse<UploadFileModel>> uploadImage(
    File file,
    String type,
  ) async {
    final response = await _supabaseService.callEdgeFunction(
      'upload-image',
      body: {
        'type': type,
        'file': file,
      },
      isFormData: true,
    );

    if (response.success) {
      // Extract the "upload" field from the response data
      final uploadFileModel = UploadFileModel.fromJson(response.data['upload']);
      return SupabaseApiResponse.success(uploadFileModel);
    } else {
      return SupabaseApiResponse.error(response.message, code: response.code);
    }
  }

  // ...existing code...
  /// Fetch stove IDs for an organization with robust type checking and logging
  Future<SupabaseApiResponse<List<StoveIdModel>>> fetchStoveIds({
    required String organizationId,
    String? status,
  }) async {
    try {
      final response = await _supabaseService.callEdgeFunction(
        'get-stove-ids',
        body: {
          'organization_id': organizationId,
          if (status != null) 'status': status,
        },
        requireAuth: true,
      );
      if (response.success) {
        final responseData = response.data;
        List<dynamic> stoveIDList;
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('data')) {
          stoveIDList = responseData['data'] as List<dynamic>;
        } else if (responseData is List<dynamic>) {
          // Direct list format
          stoveIDList = responseData;
        } else {
          logger.e('Unexpected response format: ${responseData.runtimeType}');
          return SupabaseApiResponse.error(
              'Unexpected response format from server');
        }

        final agents =
            stoveIDList.map((json) => StoveIdModel.fromJson(json)).toList();
        return SupabaseApiResponse.success(agents);
      } else {
        return SupabaseApiResponse.error(response.message, code: response.code);
      }
    } catch (e, stack) {
      logger.e('Error in fetchStoveIds: $e\n$stack');
      return SupabaseApiResponse.error('An unexpected error occurred');
    }
  }
}
