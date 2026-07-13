import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/features/agents/models/agent_model.dart';

const _cacheKey = 'cache_agents';

/// Loads the full agent list (ACSL agents + partner agents) for super admin.
/// Offline-first: serves cache immediately, refreshes from `super-admin-agents`
/// when online. Route data through `callEdgeFunction` only (never Supabase.from).
class AgentsNotifier extends AsyncNotifier<List<AgentModel>> {
  @override
  Future<List<AgentModel>> build() => _load();

  Future<List<AgentModel>> _load() async {
    final cache = ref.read(localCacheProvider);
    final connectivity = ref.read(connectivityProvider);

    final cached = cache
        .getJsonList(_cacheKey)
        .map((e) => AgentModel.fromJson(e))
        .toList();

    if (!connectivity.isOnline.value) {
      if (cached.isEmpty) {
        throw 'No internet connection. Connect to load agents.';
      }
      return cached;
    }

    final resp = await ref.read(supabaseServiceProvider).callEdgeFunction(
          'super-admin-agents',
          body: {},
          method: 'GET',
        );

    if (!resp.success || resp.data == null) {
      if (cached.isNotEmpty) return cached;
      throw resp.message;
    }

    final rows = _extractRows(resp.data);
    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => AgentModel.fromJson(e)).toList();
  }

  /// Pull-to-refresh / retry.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Edge functions return either a bare list or `{ data: [...] }`.
  List<Map<String, dynamic>> _extractRows(dynamic data) {
    final List raw = data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? data['agents'] as List? ?? []) : []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final agentsProvider =
    AsyncNotifierProvider<AgentsNotifier, List<AgentModel>>(AgentsNotifier.new);
