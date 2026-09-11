import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'package:stove_transaction/core/model/sale_field_dictionary.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';

/// Fetches and caches the sale field dictionary.
///
/// One source of truth for the sale form's wording, its choices and the day
/// each field becomes mandatory. Read at run time so an administrator can move
/// a date or relabel a field without an app release.
///
/// Three layers, in the order they are consulted:
///
///  1. **The endpoint** — `GET /functions/v1/sale-dictionary`, revalidated with
///     `If-None-Match`. A 304 costs almost nothing, so this is called at
///     sign-in and on every resume.
///  2. **The offline cache** — the last good answer, kept with its ETag. This is
///     what a field agent with no signal uses, and it is why a sale can still
///     be created down a bad road.
///  3. **The bundled fallback** — `assets/data/sale-dictionary.json`, the seed
///     copy shipped with the build. Used only on a cold first install with no
///     network, so a brand-new agent is never handed an empty form.
///
/// Goes through [SupabaseService.callEdgeFunction] like every other call — no
/// raw HTTP, no direct table query.
class SaleDictionaryService extends GetxService {
  static const String _functionName = 'sale-dictionary';
  static const String _cacheKey = 'cache_sale_dictionary';
  static const String _bundledAsset = 'assets/data/sale-dictionary.json';

  final SupabaseService _supabase = Get.find<SupabaseService>();
  final LocalCacheService _cache = Get.find<LocalCacheService>();
  final Logger _logger = Logger();

  /// The dictionary currently in force. Null only before the first load.
  SaleFieldDictionary? _current;
  SaleFieldDictionary? get current => _current;

  /// Loads the best copy available without going to the network.
  ///
  /// Call this at start-up so the form has wording before the first fetch
  /// returns. Cache first, then the bundled seed.
  SaleFieldDictionary? loadCached() {
    if (_current != null) return _current;

    final stored = _cache.getJsonMap(_cacheKey);
    if (stored != null) {
      try {
        _current = SaleFieldDictionary.fromJson(stored);
        _logger.i(
          'Sale dictionary restored from cache (version ${_current!.version})',
        );
        return _current;
      } catch (e) {
        // A corrupt blob must not take down the sale form: fall through to the
        // bundled seed rather than throwing.
        _logger.w('Cached sale dictionary could not be decoded: $e');
      }
    }
    return null;
  }

  /// Loads the seed copy shipped with the build.
  ///
  /// Async because it reads an asset, so it is separate from [loadCached].
  Future<SaleFieldDictionary?> loadBundled() async {
    try {
      final raw = await rootBundle.loadString(_bundledAsset);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final dict = SaleFieldDictionary.fromJson(decoded);
      _logger.i('Sale dictionary loaded from bundle (version ${dict.version})');
      return dict;
    } catch (e) {
      _logger.e('Bundled sale dictionary could not be read: $e');
      return null;
    }
  }

  /// The dictionary, loading a cached or bundled copy if nothing is in memory.
  ///
  /// Never returns null once the app has a bundle, so callers do not need a
  /// null branch for the ordinary case.
  Future<SaleFieldDictionary?> ensureLoaded() async {
    final cached = loadCached();
    if (cached != null) return cached;
    _current = await loadBundled();
    return _current;
  }

  /// Fetches from the server, revalidating with the cached ETag.
  ///
  /// Returns the dictionary in force afterwards. On any failure the previous
  /// copy is kept and returned — a dead network or a 500 must never blank the
  /// sale form. Safe to call often; a 304 is cheap.
  Future<SaleFieldDictionary?> refresh() async {
    await ensureLoaded();
    final etag = _current?.etag;

    try {
      final resp = await _supabase.callEdgeFunction(
        _functionName,
        body: const {},
        method: 'GET',
        returnHeaders: true,
        extraHeaders: (etag != null && etag.isNotEmpty)
            ? {'If-None-Match': etag}
            : null,
      );

      if (resp.code == 304) {
        _logger.d('Sale dictionary unchanged (304)');
        return _current;
      }

      if (!resp.success || resp.data == null) {
        _logger.w('Sale dictionary refresh failed: ${resp.message}');
        return _current;
      }

      final body = resp.data;
      if (body is! Map) {
        _logger.w('Sale dictionary refresh returned an unexpected shape');
        return _current;
      }

      final fresh = SaleFieldDictionary.fromJson(
        body.cast<String, dynamic>(),
        etag: resp.headers['etag'],
        fetchedAt: DateTime.now(),
      );

      // A body with no fields is not an answer worth caching — keep what works.
      if (fresh.fields.isEmpty) {
        _logger.w('Sale dictionary refresh returned no fields; keeping cache');
        return _current;
      }

      _current = fresh;
      _cache.saveJsonMap(_cacheKey, fresh.toJson());
      _logger.i(
        'Sale dictionary refreshed (version ${fresh.version}, '
        '${fresh.fields.length} fields)',
      );
      return _current;
    } catch (e) {
      _logger.e('Sale dictionary refresh threw: $e');
      return _current;
    }
  }
}
