import 'dart:io';
import 'package:stove_transaction/admin/sales/model/sale_model.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

import 'package:logger/logger.dart';

class SaleApiService {
  final SupabaseService _supabaseService;

  SaleApiService(this._supabaseService);
  Logger logger = Logger();

  Future<SupabaseApiResponse<PaginatedSales>> fetchSales({
    int page = 1,
    int limit = 50,
    String? query, // Can be stoveSerialNo or transactionId
    String? from,
    String? to,
    String? state,
    String? lga,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (query != null && query.isNotEmpty) 'query': query,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      if (state != null && state.isNotEmpty) 'state': state,
      if (lga != null && lga.isNotEmpty) 'lga': lga,
    };

    final response = await _supabaseService.callEdgeFunction(
      'get-sales',
      body: {},
      requireAuth: true,
      queryParams: queryParams,
    );

    if (response.success) {
      final raw = response.data as Map<String, dynamic>;
      final paginatedSales = PaginatedSales.fromJson(raw);
      return SupabaseApiResponse.success(paginatedSales);
    } else {
      return SupabaseApiResponse.error(response.message, code: response.code);
    }
  }

  Future<SupabaseApiResponse<dynamic>> updateSale({
    required String saleId,
    required Map<String, dynamic> saleData,
  }) async {
    final response = await _supabaseService.callEdgeFunction(
      'update-sale',
      body: saleData,
      requireAuth: true,
      queryParams: {'id': saleId},
    );

    if (response.success) {
      return SupabaseApiResponse.success(response.data);
    } else {
      return SupabaseApiResponse.error(response.message, code: response.code);
    }
  }

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

class PaginatedSales {
  final List<SaleModel> sales;
  final PaginationInfo pagination;

  PaginatedSales({required this.sales, required this.pagination});

  factory PaginatedSales.fromJson(Map<String, dynamic> json) {
    final salesData = json['sales'] as List<dynamic>;
    final salesList = salesData.map((e) => SaleModel.fromJson(e)).toList();
    final pagination = PaginationInfo.fromJson(json['pagination']);
    return PaginatedSales(sales: salesList, pagination: pagination);
  }
}
