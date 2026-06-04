import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/widgets/empty_state.dart';
import 'package:stove_transaction/core/widgets/offline_banner.dart';
import 'package:stove_transaction/features/partners/models/partner_model.dart';
import 'partners_controller.dart';

class PartnersScreen extends StatelessWidget {
  const PartnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PartnersController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Partners'),
        actions: [
          Obx(() => PopupMenuButton<PartnerSort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort partners',
            initialValue: c.sortBy.value,
            onSelected: (v) => c.sortBy.value = v,
            itemBuilder: (_) => const [
              PopupMenuItem(value: PartnerSort.name, child: Text('Sort by Name')),
              PopupMenuItem(value: PartnerSort.stovesSold, child: Text('Sort by Stoves Sold')),
              PopupMenuItem(value: PartnerSort.stovesReceived, child: Text('Sort by Stoves Received')),
            ],
          )),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Obx(() => TextField(
              onChanged: (v) => c.searchQuery.value = v,
              decoration: InputDecoration(
                hintText: 'Search partners…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: c.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => c.searchQuery.value = '',
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
              ),
            )),
          ),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value) return const Center(child: CircularProgressIndicator());
              if (c.error.value.isNotEmpty) {
                return EmptyState(message: c.error.value, icon: Icons.error_outline, actionLabel: 'Retry', onAction: c.fetchPartners);
              }
              if (c.partners.isEmpty) {
                return const EmptyState(message: 'No partners assigned yet.', icon: Icons.people_outline);
              }
              final displayed = c.displayedPartners;
              if (displayed.isEmpty) {
                return const EmptyState(message: 'No partners match your search.', icon: Icons.search_off_outlined);
              }
              return RefreshIndicator(
                onRefresh: c.fetchPartners,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: displayed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _PartnerCard(partner: displayed[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final PartnerModel partner;
  const _PartnerCard({required this.partner});

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                partner.partnerName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            if (partner.branch.isNotEmpty || partner.state.isNotEmpty)
              Text(
                [if (partner.branch.isNotEmpty) partner.branch, if (partner.state.isNotEmpty) partner.state].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.brandPrimary),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showDetailsSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2_outlined, color: AppColors.brandPrimary),
              title: const Text('View Stove IDs'),
              onTap: () {
                Navigator.pop(context);
                _showStoveIdsSheet(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => _PartnerDetailsSheet(
          partner: partner,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showStoveIdsSheet(BuildContext context) {
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
        builder: (ctx, scrollController) => _StoveIdsSheet(
          partner: partner,
          scrollController: scrollController,
        ),
      ),
    );
  }

  /// Returns the status based on sold/allocated ratio.
  /// Green (High Sales): >= 90% sold
  /// Yellow (Mid Sales): 65%–89% sold
  /// Red (Low Sales): < 65% sold
  _PartnerStatus _status() {
    final allocated = partner.stovesAllocated;
    final sold = partner.stovesSold;
    if (allocated == 0) return _PartnerStatus.red;
    final ratio = sold / allocated;
    if (ratio >= 0.90) return _PartnerStatus.green;
    if (ratio >= 0.65) return _PartnerStatus.yellow;
    return _PartnerStatus.red;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    final accentColor = status.accentColor;
    final progressRatio = partner.stovesAllocated > 0
        ? (partner.stovesSold / partner.stovesAllocated).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: () => _showOptions(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandPrimary.withValues(alpha: 0.07),
              AppColors.brandPrimary.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
                  child: Text(partner.initials, style: TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partner.partnerName, style: Theme.of(context).textTheme.titleMedium),
                      if (partner.branch.isNotEmpty || partner.state.isNotEmpty)
                        Text(
                          [if (partner.branch.isNotEmpty) partner.branch, if (partner.state.isNotEmpty) partner.state].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                // Status badge — this is where the red/orange/green color lives
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar — status color shows here too
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressRatio,
                backgroundColor: accentColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatChip(label: 'Received', value: '${partner.stovesAllocated}', color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                _StatChip(label: 'Sold', value: '${partner.stovesSold}', color: AppColors.brandPrimary),
                const Spacer(),
                Text(
                  '${(progressRatio * 100).round()}% sold',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                ),
              ],
            ),
            if (partner.contactPerson != null || partner.contactPhone != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.person_outline, size: 14, color: AppColors.brandPrimary.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(partner.contactPerson ?? partner.contactPhone ?? '', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

enum _PartnerStatus { green, yellow, red }

extension _PartnerStatusX on _PartnerStatus {
  Color get accentColor {
    switch (this) {
      case _PartnerStatus.green: return const Color(0xFF15803D);
      case _PartnerStatus.yellow: return const Color(0xFFB45309);
      case _PartnerStatus.red: return const Color(0xFFB91C1C);
    }
  }

  String get label {
    switch (this) {
      case _PartnerStatus.green: return 'High Sales';
      case _PartnerStatus.yellow: return 'Mid Sales';
      case _PartnerStatus.red: return 'Low Sales';
    }
  }
}

class _PartnerDetailsSheet extends StatelessWidget {
  final PartnerModel partner;
  final ScrollController scrollController;
  const _PartnerDetailsSheet({required this.partner, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: AppColors.brandPrimary.withValues(alpha: 0.1))),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Partner Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(partner.partnerName, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Partner Information',
                child: Column(children: [
                  _DetailRow(label: 'Partner Name', value: partner.partnerName),
                  _DetailRow(label: 'Branch', value: partner.branch.isNotEmpty ? partner.branch : null),
                  _DetailRow(label: 'State', value: partner.state.isNotEmpty ? partner.state : null),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Contact Information',
                child: Column(children: [
                  _DetailRow(label: 'Contact Person', value: partner.contactPerson),
                  _DetailRow(label: 'Contact Phone', value: partner.contactPhone),
                  _DetailRow(label: 'Email', value: partner.email),
                  _DetailRow(label: 'Address', value: partner.address),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Stove Summary',
                child: Row(
                  children: [
                    Expanded(child: _StatTile(label: 'Stoves Received', value: '${partner.stovesAllocated}', color: AppColors.brandPrimary)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatTile(label: 'Stoves Sold', value: '${partner.stovesSold}', color: AppColors.success)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brandPrimary, letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Divider(height: 1, color: AppColors.brandPrimary.withValues(alpha: 0.2)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(value ?? 'N/A', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}

// ── Stove IDs Sheet ────────────────────────────────────────────────────────────

class _StoveIdsSheet extends StatefulWidget {
  final PartnerModel partner;
  final ScrollController scrollController;
  const _StoveIdsSheet({required this.partner, required this.scrollController});

  @override
  State<_StoveIdsSheet> createState() => _StoveIdsSheetState();
}

class _StoveIdsSheetState extends State<_StoveIdsSheet> {
  final _supabase = Get.find<SupabaseService>();
  final _cache = Get.find<LocalCacheService>();
  final _connectivity = Get.find<ConnectivityService>();
  String _statusFilter = 'all';
  String _search = '';
  bool _loading = false;
  bool _fromCache = false;
  String? _error;
  List<Map<String, dynamic>> _stoveIds = [];
  Map<String, dynamic>? _totals;

  @override
  void initState() {
    super.initState();
    _fetchStoveIds();
  }

  Future<void> _fetchStoveIds() async {
    setState(() { _loading = true; _error = null; _fromCache = false; });

    if (!_connectivity.isOnline.value) {
      // Load from per-org stove cache
      final cached = _cache.getStovesForOrg(widget.partner.id);
      if (!mounted) return;
      if (cached.isNotEmpty) {
        final filtered = _statusFilter == 'all'
            ? cached
            : cached.where((s) => s.status == _statusFilter).toList();
        final stoveMaps = filtered.map((s) => {'stove_id': s.stoveId, 'status': s.status}).toList();
        final available = cached.where((s) => s.status == 'available').length;
        final sold = cached.where((s) => s.status == 'sold').length;
        setState(() {
          _stoveIds = stoveMaps;
          _totals = {'total_stove_ids': cached.length, 'total_stove_available': available, 'total_stove_sold': sold};
          _loading = false;
          _fromCache = true;
        });
      } else {
        setState(() { _error = 'No internet connection. Sync data while online to view stove IDs offline.'; _loading = false; });
      }
      return;
    }

    final body = <String, dynamic>{'organization_id': widget.partner.id, 'limit': 500, 'offset': 0};
    if (_statusFilter != 'all') body['status'] = _statusFilter;
    final resp = await _supabase.callEdgeFunction('get-stove-ids', body: body);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      final data = resp.data is Map ? resp.data as Map : {};
      setState(() {
        _stoveIds = List<Map<String, dynamic>>.from((data['data'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _totals = data['totals'] != null ? Map<String, dynamic>.from(data['totals'] as Map) : null;
        _loading = false;
      });
    } else {
      setState(() { _error = resp.message; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _stoveIds;
    return _stoveIds.where((s) => (s['stove_id'] as String? ?? '').toLowerCase().contains(_search.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = (_totals?['total_stove_ids'] as num?)?.toInt() ?? 0;
    final available = (_totals?['total_stove_available'] as num?)?.toInt() ?? 0;
    final sold = (_totals?['total_stove_sold'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: AppColors.brandPrimary.withValues(alpha: 0.1))),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Stove IDs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (_fromCache) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Cached', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            Text(widget.partner.partnerName, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),

        // Totals row
        if (_totals != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(children: [
              _TotalBadge(label: 'Total', value: total, color: Colors.grey[700]!),
              const SizedBox(width: 8),
              _TotalBadge(label: 'Received', value: available, color: AppColors.brandPrimary),
              const SizedBox(width: 8),
              _TotalBadge(label: 'Sold', value: sold, color: AppColors.success),
            ]),
          ),

        // Filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search stove ID...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _statusFilter,
              isDense: true,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'available', child: Text('Available')),
                DropdownMenuItem(value: 'sold', child: Text('Sold')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _statusFilter = v);
                _fetchStoveIds();
              },
            ),
          ]),
        ),

        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchStoveIds, child: const Text('Retry')),
                      ]),
                    )
                  : _filtered.isEmpty
                      ? const Center(child: Text('No stove IDs found.', style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 2.8,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final stove = _filtered[i];
                            final isSold = stove['status'] == 'sold';
                            return Container(
                              decoration: BoxDecoration(
                                color: isSold ? const Color(0xFF166534) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSold ? const Color(0xFF166534) : Colors.grey[300]!,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                stove['stove_id'] as String? ?? '',
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

class _TotalBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _TotalBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: '$value ', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          TextSpan(text: label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: '$value ', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          TextSpan(text: label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
        ]),
      ),
    );
  }
}
