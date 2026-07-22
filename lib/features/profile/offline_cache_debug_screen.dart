import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';

/// Hidden diagnostics page (reached by tapping the profile "Data Sync" title 5×).
///
/// Shows EXACTLY what is cached offline — every partner and how many stove IDs
/// were downloaded for each — so we can verify the field device holds the full
/// dataset (900+ partners, 17k+ stoves) and isn't silently truncated. Read-only
/// except for a manual "Re-download everything" trigger.
class OfflineCacheDebugScreen extends StatefulWidget {
  const OfflineCacheDebugScreen({super.key});

  @override
  State<OfflineCacheDebugScreen> createState() => _OfflineCacheDebugScreenState();
}

class _OfflineCacheDebugScreenState extends State<OfflineCacheDebugScreen> {
  final _cache = Get.find<LocalCacheService>();
  final _refresh = Get.find<DataRefreshService>();
  final _connectivity = Get.find<ConnectivityService>();

  late List<_OrgCacheRow> _rows;
  int _totalStoves = 0;
  int _orgsWithZero = 0;
  int _globalModels = 0;
  int _cachedPhones = 0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    final partners = _cache.getAssignedPartners();
    final rows = <_OrgCacheRow>[];
    var totalStoves = 0;
    var zero = 0;
    for (final p in partners) {
      final id = p['id']?.toString() ?? '';
      final name = (p['partner_name'] ?? p['name'] ?? '(unnamed)').toString();
      final stoveCount = id.isEmpty ? 0 : _cache.getStovesForOrg(id).length;
      totalStoves += stoveCount;
      if (stoveCount == 0) zero++;
      rows.add(_OrgCacheRow(
        id: id,
        name: name,
        state: p['state']?.toString() ?? '',
        stoves: stoveCount,
      ));
    }
    // Payment models are global (one list for all partners), cached once.
    _globalModels = _cache.getPaymentModels().length;
    // End-user phones are global too, and role-independent — the count should
    // read the same for every logged-in user. A number that differs between
    // accounts means the phone sync is being scoped somewhere it shouldn't be.
    _cachedPhones = _cache.endUserPhoneCount;
    // Surface partners with 0 cached stoves first — those are the suspicious ones.
    rows.sort((a, b) => a.stoves.compareTo(b.stoves));
    setState(() {
      _rows = rows;
      _totalStoves = totalStoves;
      _orgsWithZero = zero;
    });
  }

  Future<void> _redownload() async {
    if (!_connectivity.isOnline.value) {
      Get.snackbar('Offline', 'Connect to the internet to re-download.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await _refresh.refreshAll();
    _compute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Cache Logs')),
      body: Column(
        children: [
          _summary(),
          const Divider(height: 1),
          Expanded(
            child: _rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No partners cached yet. Connect and re-download.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _orgTile(_rows[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        final busy = _refresh.isRefreshing.value;
        return FloatingActionButton.extended(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          icon: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download),
          label: Text(busy ? 'Downloading…' : 'Re-download all'),
          onPressed: busy ? null : _redownload,
        );
      }),
    );
  }

  Widget _summary() {
    final lastAt = _refresh.lastRefreshedAt.value;
    final lastLabel = lastAt == null
        ? 'never'
        : DateFormat('d MMM yyyy, h:mm a').format(lastAt);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two rows of three: five tiles across one row squeezes each to ~65px
          // on a 360dp screen and the longer labels overflow.
          Row(
            children: [
              _stat('Partners', '${_rows.length}'),
              const SizedBox(width: 12),
              _stat('Stove IDs', '$_totalStoves'),
              const SizedBox(width: 12),
              _stat('Payment models', '$_globalModels'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Phone numbers', '$_cachedPhones'),
              const SizedBox(width: 12),
              _stat('Empty partners', '$_orgsWithZero',
                  danger: _orgsWithZero > 0),
              const SizedBox(width: 12),
              // Keeps the two rows on the same 3-column grid.
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 10),
          Text('Last full download: $lastLabel',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (_orgsWithZero > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$_orgsWithZero partner(s) have 0 cached stoves — they may just have '
                'no available stock, or the download was interrupted. Re-download to be sure.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {bool danger = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: danger ? AppColors.warning : AppColors.borderColor),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: danger ? AppColors.warning : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _orgTile(_OrgCacheRow r) {
    return ListTile(
      dense: true,
      title: Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${r.state.isEmpty ? '—' : r.state}\n${r.id}',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      isThreeLine: true,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: r.stoves == 0 ? AppColors.offlineBanner : AppColors.brandLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('${r.stoves} stoves',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: r.stoves == 0 ? AppColors.offlineBannerText : AppColors.brandPrimary)),
      ),
    );
  }
}

class _OrgCacheRow {
  final String id;
  final String name;
  final String state;
  final int stoves;
  _OrgCacheRow({
    required this.id,
    required this.name,
    required this.state,
    required this.stoves,
  });
}
