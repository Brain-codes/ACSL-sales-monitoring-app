import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/location_resolution_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';

/// Lets the user confirm the correct Google location for offline sales whose
/// typed address didn't confidently match at sync time. Picking a suggestion
/// (or keeping the typed address) clears the sale to sync.
class LocationResolutionScreen extends StatefulWidget {
  const LocationResolutionScreen({super.key});

  @override
  State<LocationResolutionScreen> createState() => _LocationResolutionScreenState();
}

class _LocationResolutionScreenState extends State<LocationResolutionScreen> {
  final _queue = Get.find<OfflineQueueService>();
  final _resolver = Get.find<LocationResolutionService>();

  bool _loading = true;
  bool _syncing = false;
  List<_PendingSale> _sales = [];

  /// Resolved payloads for cards the user has confirmed, keyed by queue id.
  /// A card only syncs once every card here is confirmed and the global button
  /// is pressed.
  final Map<int, Map<String, dynamic>> _confirmed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _queue.getNeedsResolution();
    _sales = rows.map(_PendingSale.fromRow).toList();
    _confirmed.clear();
    if (mounted) setState(() => _loading = false);
  }

  bool get _allConfirmed =>
      _sales.isNotEmpty && _confirmed.length == _sales.length;

  /// Records a card's confirmed resolution locally (no sync yet).
  void _recordConfirm(
      _PendingSale sale, PlaceCandidate? chosen, String editedAddress) {
    final resolved = chosen == null
        ? _keepTyped(sale.payload, editedAddress)
        : _resolver.applyCandidateToPayload(sale.payload, chosen);
    setState(() => _confirmed[sale.id] = resolved);
  }

  /// Re-opens a confirmed card for editing.
  void _reopen(_PendingSale sale) {
    setState(() => _confirmed.remove(sale.id));
  }

  /// Applies every confirmed resolution, then syncs them all.
  Future<void> _confirmAllAndSync() async {
    if (!_allConfirmed || _syncing) return;
    setState(() => _syncing = true);
    for (final entry in _confirmed.entries) {
      await _queue.applyResolution(entry.key, entry.value);
    }
    // Only sync the sales we just resolved here — NOT every queued sale. Passing
    // onlyIds keeps this screen's action scoped to the addresses the user is
    // fixing up, instead of pushing all pending sales at once.
    await Get.find<SyncService>().syncPendingSales(
      onlyIds: _confirmed.keys.toList(),
    );
    if (!mounted) return;
    setState(() => _syncing = false);
    if (_queue.needsResolutionCount.value == 0) {
      Navigator.of(context).pop();
    } else {
      _load();
    }
  }

  /// Keeps the (possibly edited) typed address — no Google candidate chosen.
  ///
  /// When the agent rejects every Google match and proceeds with their own
  /// typed text, we deliberately ZERO the coordinates (lat/lng = 0,0): the sale
  /// then relies solely on the free-typed full address, with no (mismatched)
  /// Google or stale captured-GPS point attached. The user's on-the-spot edit
  /// is persisted into the payload.
  Map<String, dynamic> _keepTyped(Map<String, dynamic> payload, String editedAddress) {
    final out = Map<String, dynamic>.from(payload);
    final addr = out['addressData'] is Map
        ? Map<String, dynamic>.from(out['addressData'] as Map)
        : <String, dynamic>{};
    final trimmed = editedAddress.trim();
    if (trimmed.isNotEmpty) addr['fullAddress'] = trimmed;
    addr['latitude'] = 0;
    addr['longitude'] = 0;
    addr['locationResolved'] = true;
    out['addressData'] = addr;
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Sale Locations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? const _EmptyState()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, i) => _SaleResolutionCard(
                          sale: _sales[i],
                          resolver: _resolver,
                          isConfirmed: _confirmed.containsKey(_sales[i].id),
                          onConfirm: _recordConfirm,
                          onReopen: _reopen,
                        ),
                      ),
                    ),
                    _GlobalSyncBar(
                      confirmedCount: _confirmed.length,
                      total: _sales.length,
                      allConfirmed: _allConfirmed,
                      syncing: _syncing,
                      onSync: _confirmAllAndSync,
                    ),
                  ],
                ),
    );
  }
}

/// Sticky bottom bar with the single global "Confirm all & Sync" action.
class _GlobalSyncBar extends StatelessWidget {
  final int confirmedCount;
  final int total;
  final bool allConfirmed;
  final bool syncing;
  final VoidCallback onSync;

  const _GlobalSyncBar({
    required this.confirmedCount,
    required this.total,
    required this.allConfirmed,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              allConfirmed
                  ? 'All $total location${total > 1 ? 's' : ''} confirmed'
                  : '$confirmedCount of $total confirmed',
              style: TextStyle(
                fontSize: 12.5,
                color: allConfirmed ? AppColors.success : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(syncing ? 'Syncing…' : 'Confirm all & Sync'),
                onPressed: (allConfirmed && !syncing) ? onSync : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: AppColors.success),
          SizedBox(height: 12),
          Text('All sale locations confirmed',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SaleResolutionCard extends StatefulWidget {
  final _PendingSale sale;
  final LocationResolutionService resolver;
  final bool isConfirmed;
  final void Function(_PendingSale, PlaceCandidate?, String) onConfirm;
  final void Function(_PendingSale) onReopen;

  const _SaleResolutionCard({
    required this.sale,
    required this.resolver,
    required this.isConfirmed,
    required this.onConfirm,
    required this.onReopen,
  });

  @override
  State<_SaleResolutionCard> createState() => _SaleResolutionCardState();
}

class _SaleResolutionCardState extends State<_SaleResolutionCard> {
  // Google auto-matches for the typed address (from sync time).
  late List<PlaceCandidate> _candidates;
  // The user's typed address as a selectable 100%-match option. Sits at the top
  // of the list; editing replaces it in place.
  late PlaceCandidate _typed;

  late final TextEditingController _editCtrl;
  int _selected = 0; // index into the combined [typed, ...candidates] list
  bool _editing = false;
  bool _searching = false;

  // Live Google autocomplete predictions shown under the edit field.
  Timer? _debounce;
  List<Map<String, String>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _candidates = List.of(widget.sale.candidates);
    _typed = _typedCandidate(widget.sale.typedAddress);
    _editCtrl = TextEditingController(text: widget.sale.typedAddress);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _editCtrl.dispose();
    super.dispose();
  }

  /// The combined option list shown as radios: the typed address first, then
  /// the Google auto-matches.
  List<PlaceCandidate> get _options => [_typed, ..._candidates];

  /// Builds the "your typed address" option (empty placeId = keep exactly what
  /// the agent typed). Coordinates are 0,0 by design: choosing this option means
  /// "trust the typed text, attach NO map location" (see [_keepTyped]).
  PlaceCandidate _typedCandidate(String text) => PlaceCandidate(
        placeId: '',
        name: '',
        formattedAddress: text.trim().isEmpty ? '(no address typed)' : text.trim(),
        lat: 0,
        lng: 0,
        score: 1,
      );

  /// Fires Google autocomplete as the user types in the edit field.
  void _onEditChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      final results = await widget.resolver.autocomplete(
        value,
        lat: widget.sale.lat,
        lng: widget.sale.lng,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  /// User tapped an autocomplete suggestion — fetch its verified location and
  /// put it at the top of the list (replacing the typed option), selected.
  Future<void> _onSuggestionTap(Map<String, String> sug) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _searching = true;
    });
    final place = await widget.resolver.placeDetails(sug['place_id'] ?? '');
    if (!mounted) return;
    setState(() {
      _searching = false;
      _editing = false;
      if (place != null) {
        _typed = place; // verified Google location becomes the top option
        _editCtrl.text = place.formattedAddress;
      }
      _selected = 0;
    });
  }

  /// Keeps the free-typed text (no suggestion picked) as the top option.
  void _applyTypedText() {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _typed = _typedCandidate(_editCtrl.text);
      _suggestions = [];
      _selected = 0;
      _editing = false;
    });
  }

  /// Display label of the currently-selected option.
  String get _selectedLabel {
    final c = _options[_selected];
    return _selected == 0 ? c.formattedAddress : c.label;
  }

  /// Coordinates of the currently-selected option — these are what get saved.
  double? get _selLat => _options[_selected].lat ?? widget.sale.lat;
  double? get _selLng => _options[_selected].lng ?? widget.sale.lng;

  Widget _coordRow() {
    final lat = _selLat, lng = _selLng;
    if (lat == null || lng == null) return const SizedBox.shrink();
    // 0,0 = the "keep my typed address, no map location" choice.
    if (lat == 0 && lng == 0) {
      return Row(
        children: [
          const Icon(Icons.location_off_outlined, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text('Address only — no GPS location',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.my_location, size: 12, color: AppColors.brandPrimary),
        const SizedBox(width: 4),
        Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 12, color: AppColors.brandPrimary)),
      ],
    );
  }

  void _confirmSelection() {
    _debounce?.cancel();
    final chosen = _options[_selected];
    widget.onConfirm(
      widget.sale,
      chosen.placeId.isEmpty ? null : chosen,
      _selected == 0 ? _typed.formattedAddress : _editCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: widget.isConfirmed ? AppColors.success : AppColors.borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${s.buyer.isEmpty ? "Sale" : s.buyer}${s.stove.isEmpty ? "" : " · ${s.stove}"}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          if (widget.isConfirmed) _buildConfirmed() else _buildEditor(s),
        ],
      ),
    );
  }

  /// Compact confirmed view: the chosen address, a Confirmed badge, and a pen
  /// icon (far right) to re-open for editing.
  Widget _buildConfirmed() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedLabel, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                _coordRow(),
                const SizedBox(height: 4),
                const Text('Confirmed',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.brandPrimary),
            tooltip: 'Edit address',
            onPressed: () => widget.onReopen(widget.sale),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(_PendingSale s) {
    final options = _options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        _coordRow(),
        const Divider(height: 20),
        const Text('Pick the correct address', style: _labelStyle),
        const SizedBox(height: 6),
        ...List.generate(options.length, (i) {
          final c = options[i];
          final isTyped = i == 0;
          return RadioListTile<int>(
            value: i,
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v ?? 0),
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.brandPrimary,
            title: Text(isTyped ? c.formattedAddress : c.label,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              isTyped ? 'Your address (no GPS location)' : '${(c.score * 100).round()}% match',
              style: TextStyle(
                  fontSize: 11,
                  color: isTyped || c.score >= 0.85
                      ? AppColors.success
                      : AppColors.textMuted),
            ),
          );
        }),
        const SizedBox(height: 4),
        if (!_editing)
          // Edit address + Confirm side by side.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18, color: AppColors.brandPrimary),
                  label: const Text('Edit address', style: TextStyle(color: AppColors.brandPrimary)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.brandPrimary)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _confirmSelection,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          )
        else ...[
          TextField(
            controller: _editCtrl,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            onChanged: _onEditChanged,
            onSubmitted: (_) => _applyTypedText(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Type to search address…',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          // Live Google autocomplete suggestions.
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: _suggestions.map((sug) {
                  final isLast = sug == _suggestions.last;
                  return InkWell(
                    onTap: () => _onSuggestionTap(sug),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(bottom: BorderSide(color: AppColors.borderColor)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(sug['description'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _searching ? null : _applyTypedText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Use this address'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _searching
                    ? null
                    : () => setState(() {
                          _editCtrl.text = _typed.formattedAddress;
                          _suggestions = [];
                          _editing = false;
                        }),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

const _labelStyle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted);

class _PendingSale {
  final int id;
  final Map<String, dynamic> payload;
  final String typedAddress;
  final double? lat;
  final double? lng;
  final String buyer;
  final String stove;
  final List<PlaceCandidate> candidates;

  _PendingSale({
    required this.id,
    required this.payload,
    required this.typedAddress,
    required this.lat,
    required this.lng,
    required this.buyer,
    required this.stove,
    required this.candidates,
  });

  factory _PendingSale.fromRow(Map<String, dynamic> row) {
    final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    final addr = payload['addressData'] is Map
        ? Map<String, dynamic>.from(payload['addressData'] as Map)
        : <String, dynamic>{};
    final candJson = row['candidates'] as String?;
    final cands = <PlaceCandidate>[];
    if (candJson != null) {
      for (final c in (jsonDecode(candJson) as List)) {
        cands.add(PlaceCandidate.fromJson(Map<String, dynamic>.from(c as Map)));
      }
    }
    return _PendingSale(
      id: row['id'] as int,
      payload: payload,
      typedAddress: (addr['fullAddress'] ?? '').toString(),
      lat: (addr['latitude'] as num?)?.toDouble(),
      lng: (addr['longitude'] as num?)?.toDouble(),
      buyer: (payload['contactPerson'] ?? '').toString(),
      stove: (payload['stoveSerialNo'] ?? '').toString(),
      candidates: cands,
    );
  }
}
