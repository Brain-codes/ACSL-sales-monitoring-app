import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/sales/services/sale_api_service.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/form/model/upload_file_model.dart'; // Import MediaType

class FormService {
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
      File file, String type) async {
    final response = await _supabaseService.callEdgeFunction(
      'upload-image',
      body: {},
      isFormData: true,
    ); // Pass the file and type to the function

    (file: file, type: type);
    if (response.success) {
      return SupabaseApiResponse.success(response.data as UploadFileModel);
    } else {
      return SupabaseApiResponse.error(response.message, code: response.code);
    }
  }
}
