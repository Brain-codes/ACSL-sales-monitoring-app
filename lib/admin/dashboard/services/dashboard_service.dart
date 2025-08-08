import 'package:logger/logger.dart';
import 'package:stove_transaction/admin/dashboard/model/dashboard_stats_model.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

class DashboardService {
  final SupabaseService _supabaseService;
  final Logger logger = Logger();

  DashboardService(this._supabaseService);

  /// Fetch dashboard statistics from Supabase edge function
  Future<SupabaseApiResponse<DashboardStatsModel>> fetchDashboardStats() async {
    try {
      logger.d('Calling get-dashboard-stats edge function...');

      final response = await _supabaseService.callEdgeFunction(
        'get-dashboard-stats',
        body: {},
        requireAuth: true,
      );

      logger.d('Raw edge function response: ${response.data}');

      if (response.success) {
        // The edge function returns: { success: true, data: { ...stats }, message: "..." }
        // We need to extract the 'data' field which contains the actual dashboard stats
        final responseData = response.data;
        final statsData = responseData['data'];

        logger.d('Extracted stats data: $statsData');

        final stats = DashboardStatsModel.fromJson(statsData);
        logger.d('Dashboard stats parsed successfully: $stats');
        return SupabaseApiResponse.success(stats);
      } else {
        logger.e('Failed to fetch dashboard stats: ${response.message}');
        return SupabaseApiResponse.error(response.message);
      }
    } catch (e) {
      logger.e('Error in fetchDashboardStats: $e');
      return SupabaseApiResponse.error(
          'An unexpected error occurred while fetching dashboard statistics');
    }
  }
}
