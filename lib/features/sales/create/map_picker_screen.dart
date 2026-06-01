import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'create_sale_controller.dart';

class MapPickerScreen extends StatefulWidget {
  final CreateSaleController controller;
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    required this.controller,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with SingleTickerProviderStateMixin {
  static const _defaultCenter = LatLng(9.082, 8.6753); // Nigeria center

  GoogleMapController? _mapCtrl;
  LatLng _pin = _defaultCenter;
  String _address = '';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;
  bool _isDragging = false;

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  // Search state
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<Map<String, String>> _suggestions = [];
  bool _isSearching = false;

  // Debounce for reverse geocode on camera idle
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 4.0).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: -4.0).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    ]).animate(_bounceCtrl);

    if (widget.initialLat != null && widget.initialLng != null) {
      _pin = LatLng(widget.initialLat!, widget.initialLng!);
      _address = widget.controller.fullAddressCtrl.text;
    } else {
      _locateUser();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _bounceCtrl.dispose();
    _mapCtrl?.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    setState(() => _isLoadingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = latlng);
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(latlng, 16));
      await _reverseGeocode(latlng);
    } catch (_) {
      // silently fall back to Nigeria center
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isLoadingAddress = true);
    final result = await widget.controller.reverseGeocode(pos.latitude, pos.longitude);
    if (mounted) {
      setState(() {
        _address = result ?? '';
        _isLoadingAddress = false;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _pin = position.target;
      _isDragging = true;
    });
    _debounce?.cancel();
  }

  void _onCameraIdle() {
    setState(() => _isDragging = false);
    HapticFeedback.lightImpact();
    _bounceCtrl.forward(from: 0);
    _debounce = Timer(const Duration(milliseconds: 300), () => _reverseGeocode(_pin));
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await widget.controller.searchPlaces(query);
    if (mounted) setState(() { _suggestions = results; _isSearching = false; });
  }

  Future<void> _onSuggestionTap(Map<String, String> suggestion) async {
    _searchCtrl.text = suggestion['description']!;
    _searchFocus.unfocus();
    setState(() => _suggestions = []);
    final details = await widget.controller.fetchPlaceDetails(suggestion['place_id']!);
    if (details != null && mounted) {
      final latlng = LatLng(details.lat, details.lng);
      setState(() {
        _pin = latlng;
        _address = details.address;
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(latlng, 16));
    }
  }

  void _confirm() {
    widget.controller.confirmMapLocation(
      lat: _pin.latitude,
      lng: _pin.longitude,
      address: _address,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pin,
              zoom: widget.initialLat != null ? 15 : 6,
            ),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
              if (widget.initialLat != null) {
                ctrl.animateCamera(CameraUpdate.newLatLngZoom(_pin, 15));
              }
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // ── Fixed center pin (Uber/Bolt style) ────────────────────────
          AnimatedBuilder(
            animation: _bounceAnim,
            builder: (context, _) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, _bounceAnim.value + (_isDragging ? -14 : 0)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.location_pin,
                          color: AppColors.brandPrimary,
                          size: _isDragging ? 48 : 42,
                          shadows: _isDragging
                              ? [const Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 6))]
                              : null,
                        ),
                      ),
                    ),
                    // Ground shadow dot — shrinks when pin is lifted
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isDragging ? 10 : 6,
                      height: _isDragging ? 3 : 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Top: back + search bar ────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      _CircleBtn(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search address...',
                              hintStyle: const TextStyle(fontSize: 14),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _suggestions = []);
                                          },
                                        )
                                      : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Suggestions dropdown ──────────────────────────────
                if (_suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: _suggestions.map((s) {
                          return InkWell(
                            onTap: () => _onSuggestionTap(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 18, color: AppColors.brandPrimary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      s['description']!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Top-left lat/lng overlay ──────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 12,
            child: AnimatedOpacity(
              opacity: _isLoadingAddress ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),

          // ── My location FAB ───────────────────────────────────────────
          Positioned(
            bottom: 100,
            right: 12,
            child: _CircleBtn(
              icon: _isLoadingLocation ? null : Icons.my_location,
              onTap: _locateUser,
              loading: _isLoadingLocation,
            ),
          ),

          // ── Address bar + Confirm ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_pin, color: AppColors.brandPrimary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isDragging
                              ? const Text(
                                  'Move to select location...',
                                  key: ValueKey('dragging'),
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
                                )
                              : _isLoadingAddress
                                  ? const Text(
                                      'Finding address...',
                                      key: ValueKey('loading'),
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                    )
                                  : Text(
                                      _address.isNotEmpty ? _address : 'Drag the map to set location',
                                      key: const ValueKey('address'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _address.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _address.isNotEmpty ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Confirm Location',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData? icon;
  final VoidCallback onTap;
  final bool loading;

  const _CircleBtn({required this.onTap, this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 20, color: AppColors.brandPrimary),
        ),
      ),
    );
  }
}
