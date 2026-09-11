import 'package:stove_transaction/core/services/supabase_service.dart';

/// Fetches EVERY row from a list edge function by paging.
///
/// M10: every list function caps a single response — transfers at 200, agents,
/// users and organizations at 100, stoves and sales at 500. Screens that asked
/// once and showed the answer were short as soon as the real count passed the
/// cap, and several asked for less than the cap on top of that (transfers 50,
/// agents 25, users 25). `has_more` was ignored everywhere.
///
/// This is the loop `PartnerAccessService._fetchAllOrganizations` already ran
/// correctly, lifted out so the other screens stop reinventing it.
///
/// Stops when the server says there is no more: a short page, `pagination.total`
/// reached, or `has_more` false. A failure on the FIRST page throws, because
/// there is nothing to show; a failure on a later page keeps what arrived,
/// because a partial list beats an empty one.
Future<List<Map<String, dynamic>>> fetchAllPages(
  SupabaseService supabase,
  String functionName, {
  int pageSize = 100,
  Map<String, dynamic> queryParams = const {},
  String? errorMessage,
  /// Extra safety valve so a server that never reports a total cannot spin
  /// forever. 200 pages at the default size is 20,000 rows.
  int maxPages = 200,
}) async {
  final all = <Map<String, dynamic>>[];
  var offset = 0;
  var pages = 0;

  while (pages < maxPages) {
    final resp = await supabase.callEdgeFunction(
      functionName,
      body: const {},
      method: 'GET',
      queryParams: {
        ...queryParams,
        'limit': pageSize,
        'offset': offset,
      },
    );

    if (!resp.success || resp.data == null) {
      if (all.isEmpty) {
        throw resp.message.isEmpty
            ? (errorMessage ?? 'Could not load $functionName')
            : resp.message;
      }
      break;
    }

    final rows = extractRows(resp.data);
    all.addAll(rows);
    pages++;

    if (rows.length < pageSize) break;
    if (hasMore(resp.data) == false) break;
    final total = totalFrom(resp.data);
    offset += pageSize;
    if (total != null && offset >= total) break;
  }

  return all;
}

/// The rows out of a list response, whatever key the function used.
List<Map<String, dynamic>> extractRows(dynamic data) {
  final List raw = data is List
      ? data
      : (data is Map
          ? (data['data'] as List? ??
              data['rows'] as List? ??
              data['items'] as List? ??
              const [])
          : const []);
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// The server's own count of matching rows, when it reports one.
int? totalFrom(dynamic data) {
  if (data is! Map) return null;
  final pagination = data['pagination'];
  if (pagination is Map) {
    final t = int.tryParse('${pagination['total']}');
    if (t != null) return t;
  }
  return int.tryParse('${data['total']}');
}

/// The server's `has_more` flag, when it reports one. Null means it did not.
bool? hasMore(dynamic data) {
  if (data is! Map) return null;
  final pagination = data['pagination'];
  if (pagination is Map && pagination.containsKey('has_more')) {
    return pagination['has_more'] == true;
  }
  if (data.containsKey('has_more')) return data['has_more'] == true;
  return null;
}
