import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/core/widgets/kpi_card.dart';
import 'package:stove_transaction/core/widgets/offline_banner.dart';
import 'package:stove_transaction/core/widgets/update_prompt_sheet.dart';
import 'package:stove_transaction/features/sales/resolve/location_resolution_banner.dart';
import 'package:stove_transaction/features/sales/models/sale_model.dart';
import 'package:stove_transaction/features/sales/models/stove_model.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DashboardController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Obx(() => DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: c.selectedYear.value,
                  dropdownColor: AppColors.brandHeader,
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.expand_more, color: Colors.white),
                  items: c.years
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (y) {
                    if (y != null) {
                      c.selectedYear.value = y;
                      c.fetchStats();
                    }
                  },
                ),
              )),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_create_sale',
        onPressed: () => context.push('/sales/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create Sale'),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const LocationResolutionBanner(),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value)
                return const Center(child: CircularProgressIndicator());
              final stats = c.stats.value;
              if (stats == null) {
                return EmptyState(
                  message: 'No data available for ${c.selectedYear.value}.',
                  icon: Icons.bar_chart_outlined,
                  actionLabel: 'Retry',
                  onAction: c.fetchStats,
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  await c.fetchStats();
                  showUpdatePromptIfNeeded();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.isStale.value) _OfflineStatsNotice(label: c.lastUpdatedLabel),
                      Text('Overview',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      // When showing cached (offline) figures, render the KPI grid
                      // grayscale + dimmed + non-interactive so it visibly reads
                      // as "not live data", not the real current totals.
                      _StaleWrapper(
                        stale: c.isStale.value,
                        child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.3,
                        children: [
                          KpiCard(
                            title: 'Stoves Received',
                            value: '${stats.stovesReceived}',
                            icon: Icons.inventory_2_outlined,
                            gradient: AppColors.gradientNavy,
                            onTap: () => _showStovesSheet(context,
                                statusFilter: null, title: 'Stoves Received'),
                          ),
                          KpiCard(
                            title: 'Stoves Sold',
                            value: '${stats.stovesSold}',
                            icon: Icons.sell_outlined,
                            gradient: AppColors.gradientTeal,
                            onTap: () => _showStovesSheet(context,
                                statusFilter: 'sold', title: 'Stoves Sold'),
                          ),
                          KpiCard(
                            title: 'Available Stoves',
                            value: '${stats.availableStoves}',
                            icon: Icons.local_fire_department_outlined,
                            gradient: AppColors.gradientPurple,
                            onTap: () => _showStovesSheet(context,
                                statusFilter: 'available',
                                title: 'Available Stoves'),
                          ),
                          KpiCard(
                            title: 'Expected Receivable',
                            value: c.fmt(stats.expectedReceivable),
                            icon: Icons.account_balance_outlined,
                            gradient: AppColors.gradientGold,
                            onTap: () => _showSalesSheet(context,
                                mode: _SalesMode.expectedReceivable),
                          ),
                          KpiCard(
                            title: 'Amount Received',
                            value: c.fmt(stats.amountReceived),
                            icon: Icons.payments_outlined,
                            gradient: AppColors.gradientGreen,
                            onTap: () => _showSalesSheet(context,
                                mode: _SalesMode.amountReceived),
                          ),
                          KpiCard(
                            title: 'Outstanding Balance',
                            value: c.fmt(stats.outstandingBalance),
                            icon: Icons.warning_amber_outlined,
                            gradient: AppColors.gradientRed,
                            onTap: () => _showSalesSheet(context,
                                mode: _SalesMode.outstandingBalance),
                          ),
                        ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showStovesSheet(BuildContext context,
      {required String? statusFilter, required String title}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _DashboardStovesSheet(
          title: title,
          statusFilter: statusFilter,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showSalesSheet(BuildContext context, {required _SalesMode mode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _DashboardSalesSheet(
          mode: mode,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ── Offline (stale) stats treatment ─────────────────────────────────────────

/// Banner shown above the KPI grid when the figures are cached offline data.
class _OfflineStatsNotice extends StatelessWidget {
  final String label;
  const _OfflineStatsNotice({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.offlineBanner,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppColors.offlineBannerText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label — not live figures. Reconnect to refresh.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.offlineBannerText, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [child] grayscale, dimmed and non-interactive when [stale] is true,
/// so cached offline stats visibly read as inactive/disabled.
class _StaleWrapper extends StatelessWidget {
  final bool stale;
  final Widget child;
  const _StaleWrapper({required this.stale, required this.child});

  // Luminance matrix — collapses all colour to grey.
  static const List<double> _greyscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    if (!stale) return child;
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscale),
        child: IgnorePointer(child: child),
      ),
    );
  }
}

// ── Stoves bottom sheet ────────────────────────────────────────────────────────

class _DashboardStovesSheet extends StatefulWidget {
  final String title;
  final String? statusFilter;
  final ScrollController scrollController;

  const _DashboardStovesSheet({
    required this.title,
    required this.statusFilter,
    required this.scrollController,
  });

  @override
  State<_DashboardStovesSheet> createState() => _DashboardStovesSheetState();
}

class _DashboardStovesSheetState extends State<_DashboardStovesSheet> {
  final _supabase = Get.find<SupabaseService>();
  final _cache = Get.find<LocalCacheService>();
  final _connectivity = Get.find<ConnectivityService>();
  final _session = Get.find<SessionManager>();

  String _search = '';
  bool _loading = false;
  bool _fromCache = false;
  String? _error;
  List<StoveModel> _stoves = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fromCache = false;
    });

    if (!_connectivity.isOnline.value) {
      _loadFromCache();
      return;
    }

    try {
      final body = <String, dynamic>{'limit': 500, 'offset': 0};
      if (widget.statusFilter != null) body['status'] = widget.statusFilter;

      // ACSL agents and managers span multiple orgs — use the agent-scoped
      // endpoint that resolves org IDs from the JWT instead of requiring organization_id.
      final String endpoint;
      if (_session.isAcslAgent || _session.isAcslAgentManager) {
        endpoint = 'get-agent-stove-ids';
      } else {
        endpoint = 'get-stove-ids';
        final orgId = _session.organizationId;
        if (orgId != null) body['organization_id'] = orgId;
      }

      final resp = await _supabase.callEdgeFunction(endpoint, body: body);
      if (!mounted) return;

      if (resp.success && resp.data != null) {
        final data = resp.data is Map ? resp.data as Map : {};
        final raw = (data['data'] as List?) ??
            (resp.data is List ? resp.data as List : <dynamic>[]);
        final stoves = raw
            .map(
                (e) => StoveModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((s) => s.stoveId.isNotEmpty)
            .toList();
        setState(() {
          _stoves = stoves;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = resp.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _loadFromCache() {
    List<StoveModel> all;
    if (_session.isAcslAgent) {
      // Aggregate from all assigned partner org caches
      final partners = _cache.getAssignedPartners();
      all = partners
          .map((p) => p['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .expand((id) => _cache.getStovesForOrg(id))
          .toList();
    } else {
      all = _cache.getStoves();
    }

    final filtered = widget.statusFilter == null
        ? all
        : all.where((s) => s.status == widget.statusFilter).toList();

    setState(() {
      _stoves = filtered;
      _loading = false;
      _fromCache = true;
      if (filtered.isEmpty && all.isEmpty) {
        _error =
            'No internet connection. Sync data while online to view stove IDs offline.';
      }
    });
  }

  List<StoveModel> get _filtered {
    if (_search.isEmpty) return _stoves;
    final q = _search.toLowerCase();
    return _stoves.where((s) => s.displayId.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.05),
            border: Border(
                bottom: BorderSide(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1))),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(widget.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (_fromCache) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Cached',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    if (!_loading && _stoves.isNotEmpty)
                      Text('${_stoves.length} stoves',
                          style: Theme.of(context).textTheme.bodySmall),
                  ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search stove ID...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center),
                        ),
                        TextButton(
                            onPressed: _fetch, child: const Text('Retry')),
                      ]),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text('No stoves found.',
                              style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 2.8,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final stove = filtered[i];
                            final isSold = stove.status == 'sold';
                            return Container(
                              decoration: BoxDecoration(
                                color: isSold
                                    ? const Color(0xFF166534)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSold
                                      ? const Color(0xFF166534)
                                      : Colors.grey[300]!,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                stove.displayId,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isSold ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ── Sales bottom sheet ─────────────────────────────────────────────────────────

enum _SalesMode { expectedReceivable, amountReceived, outstandingBalance }

class _DashboardSalesSheet extends StatefulWidget {
  final _SalesMode mode;
  final ScrollController scrollController;

  const _DashboardSalesSheet(
      {required this.mode, required this.scrollController});

  @override
  State<_DashboardSalesSheet> createState() => _DashboardSalesSheetState();
}

class _DashboardSalesSheetState extends State<_DashboardSalesSheet> {
  final _supabase = Get.find<SupabaseService>();
  final _cache = Get.find<LocalCacheService>();
  final _connectivity = Get.find<ConnectivityService>();

  bool _loading = false;
  bool _fromCache = false;
  String? _error;
  List<SaleModel> _sales = [];

  final _naira =
      NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  String fmt(double? v) => _naira.format(v ?? 0);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fromCache = false;
    });

    if (!_connectivity.isOnline.value) {
      _loadFromCache();
      return;
    }

    try {
      final resp = await _supabase.callEdgeFunction(
        'get-sales-advanced',
        body: {'page': 1, 'limit': 500, 'responseFormat': 'format2'},
      );
      if (!mounted) return;

      if (resp.success && resp.data != null) {
        List raw = [];
        if (resp.data is List) {
          raw = resp.data as List;
        } else if (resp.data is Map) {
          raw = (resp.data as Map)['data'] as List? ??
              (resp.data as Map)['sales'] as List? ??
              [];
        }
        final all = raw
            .map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        setState(() {
          _sales = _applyFilter(all);
          _loading = false;
        });
      } else {
        setState(() {
          _error = resp.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _loadFromCache() {
    final all = _cache.getSales();
    setState(() {
      _sales = _applyFilter(all);
      _loading = false;
      _fromCache = true;
      if (all.isEmpty)
        _error =
            'No internet connection. Sync data while online to view sales offline.';
    });
  }

  List<SaleModel> _applyFilter(List<SaleModel> all) {
    switch (widget.mode) {
      case _SalesMode.expectedReceivable:
        return all;
      case _SalesMode.amountReceived:
        return all.where((s) => (s.totalPaid ?? 0) > 0).toList();
      case _SalesMode.outstandingBalance:
        return all.where((s) {
          final amt = s.amount ?? 0;
          final paid = s.totalPaid ?? 0;
          return amt > paid;
        }).toList();
    }
  }

  String get _sheetTitle {
    switch (widget.mode) {
      case _SalesMode.expectedReceivable:
        return 'Expected Receivable';
      case _SalesMode.amountReceived:
        return 'Amount Received';
      case _SalesMode.outstandingBalance:
        return 'Outstanding Balance';
    }
  }

  Color get _accentColor {
    switch (widget.mode) {
      case _SalesMode.expectedReceivable:
        return const Color(0xFFB45309);
      case _SalesMode.amountReceived:
        return AppColors.success;
      case _SalesMode.outstandingBalance:
        return const Color(0xFFDC2626);
    }
  }

  double _keyAmount(SaleModel s) {
    switch (widget.mode) {
      case _SalesMode.expectedReceivable:
        return s.amount ?? 0;
      case _SalesMode.amountReceived:
        return s.totalPaid ?? 0;
      case _SalesMode.outstandingBalance:
        return (s.amount ?? 0) - (s.totalPaid ?? 0);
    }
  }

  double get _total => _sales.fold(0.0, (sum, s) => sum + _keyAmount(s));

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            border: Border(
                bottom: BorderSide(color: accent.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(_sheetTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (_fromCache) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Cached',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    if (!_loading && _sales.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_sales.length} sale${_sales.length == 1 ? '' : 's'}  ·  ${fmt(_total)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ]),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center),
                        ),
                        TextButton(
                            onPressed: _fetch, child: const Text('Retry')),
                      ]),
                    )
                  : _sales.isEmpty
                      ? const Center(
                          child: Text('No sales found.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _sales.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _SaleRow(
                            sale: _sales[i],
                            amount: _keyAmount(_sales[i]),
                            accentColor: accent,
                            fmt: fmt,
                          ),
                        ),
        ),
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  final SaleModel sale;
  final double amount;
  final Color accentColor;
  final String Function(double?) fmt;

  const _SaleRow({
    required this.sale,
    required this.amount,
    required this.accentColor,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final name = sale.endUserName ?? sale.contactPerson ?? 'Unknown';
    final stoveId = sale.stoveId ?? sale.stoveSerialNo ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accentColor.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text('ID: $stoveId · ${sale.state ?? ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt(amount),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: accentColor)),
              // if (payStatus.isNotEmpty)
              //   Container(
              //     margin: const EdgeInsets.only(top: 2),
              //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              //     decoration: BoxDecoration(
              //       color: _statusColor(payStatus).withValues(alpha: 0.12),
              //       borderRadius: BorderRadius.circular(4),
              //     ),
              //     child: Text(
              //       payStatus.replaceAll('_', ' '),
              //       style: TextStyle(fontSize: 10, color: _statusColor(payStatus), fontWeight: FontWeight.w600),
              //     ),
              //   ),
            ],
          ),
        ],
      ),
    );
  }
}

