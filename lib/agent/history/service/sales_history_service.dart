import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:stove_transaction/agent/history/model/sales_history_model.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class SalesHistoryService {
  final SupabaseService _supabaseService;
  final Logger logger = Logger();

  SalesHistoryService(this._supabaseService);

  /// Fetch sales history with filters and pagination
  Future<SupabaseApiResponse<HistoryResponseModel>> getSalesHistory({
    String? saleId,
    String? actionType,
    int page = 1,
    int limit = 20,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      logger.i(
          'Fetching sales history with filters: saleId=$saleId, actionType=$actionType, page=$page');

      final body = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (saleId != null) body['sale_id'] = saleId;
      if (actionType != null) body['action_type'] = actionType;
      if (dateFrom != null) body['date_from'] = dateFrom.toIso8601String();
      if (dateTo != null) body['date_to'] = dateTo.toIso8601String();

      final response = await _supabaseService.callEdgeFunction(
        'get-sales-history',
        body: body,
        requireAuth: true,
      );

      if (response.success) {
        logger.i('Raw response data type: ${response.data.runtimeType}');
        logger.i('Raw response data: ${response.data}');

        // Check if response.data is already a Map or needs parsing
        Map<String, dynamic> responseData;
        if (response.data is String) {
          logger.w('Response data is String, attempting to parse JSON');
          try {
            responseData = json.decode(response.data as String);
          } catch (parseError) {
            logger.e('Failed to parse JSON response: $parseError');
            return SupabaseApiResponse.error('Invalid response format');
          }
        } else if (response.data is Map<String, dynamic>) {
          responseData = response.data as Map<String, dynamic>;
        } else {
          logger
              .e('Unexpected response data type: ${response.data.runtimeType}');
          return SupabaseApiResponse.error('Unexpected response format');
        }

        final historyResponse = HistoryResponseModel.fromJson(responseData);
        logger.i(
            'Successfully fetched ${historyResponse.data.length} history records');
        return SupabaseApiResponse.success(historyResponse);
      } else {
        logger.e('Failed to fetch sales history: ${response.message}');
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error in getSalesHistory: $e');
      return SupabaseApiResponse.error('Failed to fetch sales history');
    }
  }

  /// Get history for a specific sale
  Future<SupabaseApiResponse<List<SalesHistoryModel>>> getSaleHistory(
      String saleId) async {
    try {
      logger.i('Fetching history for sale: $saleId');

      final response = await getSalesHistory(saleId: saleId, limit: 100);

      if (response.success && response.data != null) {
        return SupabaseApiResponse.success(response.data!.data);
      } else {
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error in getSaleHistory: $e');
      return SupabaseApiResponse.error('Failed to fetch sale history');
    }
  }

  /// Get activity stats for the current user
  Future<SupabaseApiResponse<HistoryStatsModel>> getActivityStats({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      logger.i('Fetching activity stats');

      final response = await getSalesHistory(
        page: 1,
        limit: 1, // We only need stats, not data
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      if (response.success && response.data != null) {
        return SupabaseApiResponse.success(response.data!.stats);
      } else {
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error in getActivityStats: $e');
      return SupabaseApiResponse.error('Failed to fetch activity stats');
    }
  }

  /// Search history by description or sale details
  Future<SupabaseApiResponse<List<SalesHistoryModel>>> searchHistory({
    required String query,
    String? actionType,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      logger.i('Searching history with query: $query');

      // For now, we'll fetch all and filter locally
      // In a production app, you'd want server-side search
      final response = await getSalesHistory(
        actionType: actionType,
        page: page,
        limit: limit,
      );

      if (response.success && response.data != null) {
        final filteredData = response.data!.data.where((history) {
          final searchText = query.toLowerCase();
          return history.actionDescription.toLowerCase().contains(searchText) ||
              (history.sale?.transactionId
                      ?.toLowerCase()
                      .contains(searchText) ??
                  false) ||
              (history.sale?.contactPerson
                      ?.toLowerCase()
                      .contains(searchText) ??
                  false) ||
              (history.sale?.endUserName?.toLowerCase().contains(searchText) ??
                  false) ||
              (history.performer?.fullName
                      ?.toLowerCase()
                      .contains(searchText) ??
                  false);
        }).toList();

        return SupabaseApiResponse.success(filteredData);
      } else {
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error in searchHistory: $e');
      return SupabaseApiResponse.error('Failed to search history');
    }
  }
}
