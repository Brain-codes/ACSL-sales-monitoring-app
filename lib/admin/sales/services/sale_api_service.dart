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

  /// Fetch sales using the advanced endpoint with more filtering options
  /// Uses format2 (database format) for Flutter app compatibility
  Future<SupabaseApiResponse<PaginatedSalesAdvanced>> fetchSalesAdvanced({
    int page = 1,
    int limit = 50,
    String? search,
    String? stoveSerialNo,
    String? endUserName,
    String? partnerName,
    String? phone,
    String? dateFrom,
    String? dateTo,
    String? createdFrom,
    String? createdTo,
    List<String>? states,
    List<String>? lgas,
    String? state,
    String? lga,
    double? amountMin,
    double? amountMax,
    List<String>? statuses,
    String? status,
    String? contactPerson,
    String? contactPhone,
    String? organizationId,
    String? sortBy,
    String? sortOrder,
    bool includeOrganization = true,
    bool includeAddress = false,
    bool includeCreator = false,
    bool includeImages = false,
  }) async {
    final body = {
      'page': page,
      'limit': limit,
      'responseFormat': 'format2', // Use format2 for Flutter app
      if (search != null && search.isNotEmpty) 'search': search,
      if (stoveSerialNo != null && stoveSerialNo.isNotEmpty) 'stoveSerialNo': stoveSerialNo,
      if (endUserName != null && endUserName.isNotEmpty) 'endUserName': endUserName,
      if (partnerName != null && partnerName.isNotEmpty) 'partnerName': partnerName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      if (createdFrom != null && createdFrom.isNotEmpty) 'createdFrom': createdFrom,
      if (createdTo != null && createdTo.isNotEmpty) 'createdTo': createdTo,
      if (states != null && states.isNotEmpty) 'states': states,
      if (lgas != null && lgas.isNotEmpty) 'lgas': lgas,
      if (state != null && state.isNotEmpty) 'state': state,
      if (lga != null && lga.isNotEmpty) 'lga': lga,
      if (amountMin != null) 'amountMin': amountMin,
      if (amountMax != null) 'amountMax': amountMax,
      if (statuses != null && statuses.isNotEmpty) 'statuses': statuses,
      if (status != null && status.isNotEmpty) 'status': status,
      if (contactPerson != null && contactPerson.isNotEmpty) 'contactPerson': contactPerson,
      if (contactPhone != null && contactPhone.isNotEmpty) 'contactPhone': contactPhone,
      if (organizationId != null && organizationId.isNotEmpty) 'organizationId': organizationId,
      if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
      if (sortOrder != null && sortOrder.isNotEmpty) 'sortOrder': sortOrder,
      'includeOrganization': includeOrganization,
      'includeAddress': includeAddress,
      'includeCreator': includeCreator,
      'includeImages': includeImages,
    };

    final response = await _supabaseService.callEdgeFunction(
      'get-sales-advanced',
      body: body,
      requireAuth: true,
    );

    if (response.success) {
      final raw = response.data as Map<String, dynamic>;
      final paginatedSales = PaginatedSalesAdvanced.fromJson(raw);
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

class PaginatedSalesAdvanced {
  final List<SaleModel> sales;
  final PaginationInfo pagination;
  final String responseFormat;
  final Map<String, dynamic>? filters;
  final Map<String, dynamic>? debug;

  PaginatedSalesAdvanced({
    required this.sales,
    required this.pagination,
    required this.responseFormat,
    this.filters,
    this.debug,
  });

  factory PaginatedSalesAdvanced.fromJson(Map<String, dynamic> json) {
    final salesData = json['data'] as List<dynamic>; // Note: 'data' not 'sales' for advanced endpoint
    final salesList = salesData.map((e) => SaleModel.fromJson(e)).toList();
    final pagination = PaginationInfo.fromJson(json['pagination']);
    
    return PaginatedSalesAdvanced(
      sales: salesList,
      pagination: pagination,
      responseFormat: json['responseFormat'] ?? 'format2',
      filters: json['filters'] as Map<String, dynamic>?,
      debug: json['debug'] as Map<String, dynamic>?,
    );
  }
}
