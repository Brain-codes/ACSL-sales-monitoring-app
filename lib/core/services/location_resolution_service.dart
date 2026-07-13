import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/config/env_config.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';

/// A Google location candidate for a typed offline address.
class PlaceCandidate {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double? lat;
  final double? lng;
  final double score; // 0..1 similarity vs the typed address

  const PlaceCandidate({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.score,
  });

  /// What we show the user as the Google suggestion.
  String get label {
    if (name.isNotEmpty && !formattedAddress.startsWith(name)) {
      return '$name, $formattedAddress';
    }
    return formattedAddress.isNotEmpty ? formattedAddress : name;
  }

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'name': name,
        'formattedAddress': formattedAddress,
        'lat': lat,
        'lng': lng,
        'score': score,
      };

  factory PlaceCandidate.fromJson(Map<String, dynamic> m) => PlaceCandidate(
        placeId: m['placeId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        formattedAddress: m['formattedAddress'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        score: (m['score'] as num?)?.toDouble() ?? 0,
      );
}

class ResolutionResult {
  final List<PlaceCandidate> candidates; // sorted by score desc
  const ResolutionResult(this.candidates);

  double get bestScore => candidates.isEmpty ? 0 : candidates.first.score;
  PlaceCandidate? get best => candidates.isEmpty ? null : candidates.first;
}

/// Resolves a typed offline address against Google at sync time. Queries Google
/// Places Text Search (biased by the captured GPS point) and scores each result
/// against the typed text. Callers auto-accept when [autoAcceptThreshold] is met,
/// otherwise route the sale to manual resolution.
class LocationResolutionService extends GetxService {
  final _logger = Logger();

  /// Minimum similarity (0..1) to auto-sync without manual review.
  static const double autoAcceptThreshold = 0.85;

  String? get _placesKey {
    final cached = Get.find<LocalCacheService>().getGoogleKeys();
    final k = cached?['placesKey'] ?? '';
    return k.isNotEmpty ? k : (EnvConfig.googlePlacesApiKey.isNotEmpty
        ? EnvConfig.googlePlacesApiKey
        : null);
  }

  Future<ResolutionResult> resolve({
    required String typedAddress,
    double? lat,
    double? lng,
  }) async {
    final key = _placesKey;
    final query = typedAddress.trim();
    if (key == null || query.isEmpty) return const ResolutionResult([]);
    try {
      final params = <String, String>{
        'query': query,
        'region': 'ng',
        'key': key,
      };
      if (lat != null && lng != null) {
        params['location'] = '$lat,$lng';
        params['radius'] = '25000';
      }
      final uri = Uri.https(
          'maps.googleapis.com', '/maps/api/place/textsearch/json', params);
      final res = await http.get(uri);
      if (res.statusCode != 200) return const ResolutionResult([]);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (body['results'] as List? ?? []);
      final candidates = <PlaceCandidate>[];
      for (final r in results) {
        final m = r as Map<String, dynamic>;
        final name = m['name'] as String? ?? '';
        final addr = m['formatted_address'] as String? ?? '';
        final loc = (m['geometry'] as Map?)?['location'] as Map?;
        final score = _similarity(query, '$name $addr');
        candidates.add(PlaceCandidate(
          placeId: m['place_id'] as String? ?? '',
          name: name,
          formattedAddress: addr,
          lat: (loc?['lat'] as num?)?.toDouble(),
          lng: (loc?['lng'] as num?)?.toDouble(),
          score: score,
        ));
      }
      candidates.sort((a, b) => b.score.compareTo(a.score));
      return ResolutionResult(candidates.take(6).toList());
    } catch (e) {
      _logger.e('Location resolve error: $e');
      return const ResolutionResult([]);
    }
  }

  /// Live Google Places autocomplete (Nigeria-restricted) for the edit field —
  /// same typeahead the create-sale form uses. Returns `{description, place_id}`.
  Future<List<Map<String, String>>> autocomplete(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final key = _placesKey;
    final q = query.trim();
    if (key == null || q.length < 3) return [];
    try {
      final params = <String, String>{
        'input': q,
        'components': 'country:ng',
        'key': key,
      };
      if (lat != null && lng != null) {
        params['location'] = '$lat,$lng';
        params['radius'] = '25000';
      }
      final uri = Uri.https(
          'maps.googleapis.com', '/maps/api/place/autocomplete/json', params);
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['predictions'] as List? ?? [])
          .map((p) => {
                'description': (p['description'] ?? '').toString(),
                'place_id': (p['place_id'] ?? '').toString(),
              })
          .toList();
    } catch (e) {
      _logger.e('Autocomplete error: $e');
      return [];
    }
  }

  /// Coordinates + formatted address for a selected autocomplete prediction.
  Future<PlaceCandidate?> placeDetails(String placeId) async {
    final key = _placesKey;
    if (key == null || placeId.isEmpty) return null;
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': placeId,
        'fields': 'geometry,formatted_address,name',
        'key': key,
      });
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>?;
      if (result == null) return null;
      final loc = (result['geometry'] as Map?)?['location'] as Map?;
      return PlaceCandidate(
        placeId: placeId,
        name: result['name'] as String? ?? '',
        formattedAddress: result['formatted_address'] as String? ?? '',
        lat: (loc?['lat'] as num?)?.toDouble(),
        lng: (loc?['lng'] as num?)?.toDouble(),
        score: 1,
      );
    } catch (e) {
      _logger.e('Place details error: $e');
      return null;
    }
  }

  /// Attaches a chosen/auto-matched Google location to a sale payload.
  /// Keeps the agent's typed address; adds Google's verified address, place id,
  /// and coordinates (accepted answer: "keep typed + attach Google").
  Map<String, dynamic> applyCandidateToPayload(
      Map<String, dynamic> payload, PlaceCandidate c) {
    final out = Map<String, dynamic>.from(payload);
    final addr = out['addressData'] is Map
        ? Map<String, dynamic>.from(out['addressData'] as Map)
        : <String, dynamic>{};
    // Preserve exactly what the agent typed.
    addr['enteredAddress'] = addr['fullAddress'];
    // Attach the verified Google location.
    addr['googlePlaceId'] = c.placeId;
    addr['googleFormattedAddress'] = c.formattedAddress;
    if (c.lat != null) addr['latitude'] = c.lat;
    if (c.lng != null) addr['longitude'] = c.lng;
    addr['locationResolved'] = true;
    out['addressData'] = addr;
    return out;
  }

  // ── Similarity ───────────────────────────────────────────────────────────────

  /// Token Dice coefficient with a substring bonus — robust for short,
  /// order-varying address strings. Returns 0..1.
  double _similarity(String a, String b) {
    final an = _normalize(a);
    final bn = _normalize(b);
    if (an.isEmpty || bn.isEmpty) return 0;
    if (bn.contains(an) || an.contains(bn)) {
      // One fully contains the other — strong match, scaled by length ratio.
      final ratio = an.length / bn.length;
      return 0.9 + 0.1 * (ratio > 1 ? 1 / ratio : ratio);
    }
    final at = an.split(' ').where((t) => t.isNotEmpty).toSet();
    final bt = bn.split(' ').where((t) => t.isNotEmpty).toSet();
    if (at.isEmpty || bt.isEmpty) return 0;
    final overlap = at.intersection(bt).length;
    return (2.0 * overlap) / (at.length + bt.length);
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\b(nigeria|road|rd|street|st|close|avenue|ave)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
