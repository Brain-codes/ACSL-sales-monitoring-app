import 'package:get/get.dart';

import 'package:stove_transaction/core/services/supabase_service.dart';

/// Resolves the partners (organizations) a user may see, via edge functions
/// (Bearer-token auth — works regardless of the Supabase client session):
///  - super_admin            -> `manage-organizations` (all orgs).
///  - acsl_agent / manager   -> `super-admin-agents/{id}/organizations`
///                              (their assigned partners + assigned-state partners).
///
/// (Direct Supabase table access was tried but RLS returns nothing because the
/// custom login does not establish a role-bearing Supabase session.)
class PartnerAccessService {
  final SupabaseService _supabase = Get.find<SupabaseService>();

  Future<List<Map<String, dynamic>>> partnersForUser({
    required String userId,
    required String? role,
  }) async {
    if (role == 'super_admin') {
      return _fetchAllOrganizations();
    }

    final resp = await _supabase.callEdgeFunction(
      'super-admin-agents/$userId/organizations',
      body: {},
      method: 'GET',
    );
    if (!resp.success || resp.data == null) {
      throw resp.message.isEmpty ? 'Could not load partners' : resp.message;
    }
    // The endpoint returns directly-assigned partners (source: "direct") AND
    // every org in the agent's assigned states (source: "state"). Show only the
    // partners explicitly assigned to this user — not the whole state.
    return _rows(resp.data)
        .where((r) => (r['source']?.toString() ?? 'direct') != 'state')
        .toList();
  }

  /// Fetches EVERY organization by paging through `manage-organizations`.
  ///
  /// The endpoint caps `limit` at 100 and defaults to 50, so a single call
  /// silently truncates to the first page — with 900+ partners that means most
  /// go missing from the offline cache, and those partners can't be picked in
  /// the field. We page with the max size until the reported total is reached.
  /// `include_admin_users=false` skips a per-org admin lookup we never use,
  /// making each page far cheaper.
  Future<List<Map<String, dynamic>>> _fetchAllOrganizations() async {
    const pageSize = 100;
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final resp = await _supabase.callEdgeFunction(
        'manage-organizations',
        body: {},
        method: 'GET',
        queryParams: {
          'limit': pageSize,
          'offset': offset,
          'include_admin_users': false,
        },
      );
      if (!resp.success || resp.data == null) {
        // First page failed → surface the error; later page failed → keep what
        // we already have rather than losing the whole set.
        if (all.isEmpty) {
          throw resp.message.isEmpty ? 'Could not load partners' : resp.message;
        }
        break;
      }
      final rows = _rows(resp.data);
      all.addAll(rows);
      final total = _total(resp.data);
      offset += pageSize;
      if (rows.length < pageSize) break;
      if (total != null && offset >= total) break;
    }
    return all;
  }

  /// Reads `pagination.total` from a manage-organizations response, if present.
  int? _total(dynamic data) {
    if (data is Map && data['pagination'] is Map) {
      return int.tryParse('${(data['pagination'] as Map)['total']}');
    }
    return null;
  }

  /// Edge fns return a bare list or a wrapper (`data` / `organizations` / `partners`).
  List<Map<String, dynamic>> _rows(dynamic data) {
    final List raw = data is List
        ? data
        : (data is Map
            ? (data['organizations'] as List? ??
                data['data'] as List? ??
                data['partners'] as List? ??
                [])
            : []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
