import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';

/// Server-computed totals for the sales set.
///
/// M8: the reports and the dashboard drill-downs used to add up whatever rows
/// happened to have been fetched. One response caps at 500 rows and production
/// holds 2,145 sales, so every figure was short — and got shorter every day.
///
/// `get-sales-advanced` with `withSummary: true` returns these computed in SQL
/// and scoped to the caller, filtered exactly as the rows are. The rule that
/// follows: **never sum rows to get a total.**
class SalesSummary {
  /// How many sales match — the real count, not the number of rows sent.
  final int total;

  /// The full value of those sales.
  final double receivable;

  /// What has actually been collected against them.
  final double collected;

  /// What is still owed.
  final double outstanding;

  final int fullyPaid;
  final int partiallyPaid;
  final int unpaid;

  /// Instalments falling due, when the server reports them.
  final int overdue;
  final int dueToday;
  final int due7;
  final int due14;
  final int due30;

  /// True when these figures were added up on the phone from cached rows
  /// because the server could not be reached. Shown to the user, so a partial
  /// figure is never passed off as the real one.
  final bool isLocalEstimate;

  const SalesSummary({
    required this.total,
    required this.receivable,
    required this.collected,
    required this.outstanding,
    this.fullyPaid = 0,
    this.partiallyPaid = 0,
    this.unpaid = 0,
    this.overdue = 0,
    this.dueToday = 0,
    this.due7 = 0,
    this.due14 = 0,
    this.due30 = 0,
    this.isLocalEstimate = false,
  });

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static int _int(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    final due = json['due'] is Map
        ? Map<String, dynamic>.from(json['due'] as Map)
        : const <String, dynamic>{};
    return SalesSummary(
      total: _int(json['total']),
      receivable: _num(json['receivable']),
      collected: _num(json['collected']),
      outstanding: _num(json['outstanding']),
      fullyPaid: _int(json['fully_paid'] ?? json['fullyPaid']),
      partiallyPaid: _int(json['partially_paid'] ?? json['partiallyPaid']),
      unpaid: _int(json['unpaid']),
      overdue: _int(due['overdue']),
      dueToday: _int(due['dueToday']),
      due7: _int(due['due7']),
      due14: _int(due['due14']),
      due30: _int(due['due30']),
    );
  }

  /// Adds up cached rows, for offline only.
  ///
  /// Explicitly flagged as an estimate: the device holds one page of a much
  /// larger set, so these figures are a floor, not a total.
  factory SalesSummary.fromCachedRows(List<SaleModel> sales) {
    var receivable = 0.0;
    var collected = 0.0;
    var fullyPaid = 0, partiallyPaid = 0, unpaid = 0;

    for (final s in sales) {
      final value = s.amount ?? s.paymentModelFixedPrice ?? 0;
      final paid = s.paidAmount;
      receivable += value;
      collected += paid;
      if (value <= 0 || paid <= 0) {
        unpaid++;
      } else if (paid + 0.005 < value) {
        partiallyPaid++;
      } else {
        fullyPaid++;
      }
    }

    return SalesSummary(
      total: sales.length,
      receivable: receivable,
      collected: collected,
      outstanding: (receivable - collected).clamp(0, double.infinity),
      fullyPaid: fullyPaid,
      partiallyPaid: partiallyPaid,
      unpaid: unpaid,
      isLocalEstimate: true,
    );
  }
}

/// The totals for the whole sales set the signed-in user can see.
///
/// Asks for a single row: the figures come from `summary`, so there is no
/// reason to pull rows the caller will not read.
final salesSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final connectivity = ref.read(connectivityProvider);

  if (!connectivity.isOnline.value) {
    final cached = ref.read(localCacheProvider).getSales();
    if (cached.isEmpty) {
      throw 'No internet connection. Connect to load the report.';
    }
    return SalesSummary.fromCachedRows(cached);
  }

  final resp = await ref.read(supabaseServiceProvider).callEdgeFunction(
        'get-sales-advanced',
        body: {
          'page': 1,
          'limit': 1,
          'responseFormat': 'format2',
          'withSummary': true,
        },
      );

  if (!resp.success || resp.data == null) {
    final cached = ref.read(localCacheProvider).getSales();
    if (cached.isNotEmpty) return SalesSummary.fromCachedRows(cached);
    throw resp.message;
  }

  final data = resp.data;
  final rawSummary = data is Map ? data['summary'] : null;
  if (rawSummary is Map) {
    return SalesSummary.fromJson(Map<String, dynamic>.from(rawSummary));
  }

  // The function answered but without a summary — an older deployment. Say so
  // rather than quietly adding up one page and calling it a total.
  final cached = ref.read(localCacheProvider).getSales();
  if (cached.isNotEmpty) return SalesSummary.fromCachedRows(cached);
  throw 'This report needs server-side totals, which this server did not return.';
});
