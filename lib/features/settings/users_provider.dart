import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/features/settings/models/user_account_model.dart';

const _cacheKey = 'cache_users';

/// User accounts (settings-user-management). Offline-first read via `manage-users`.
class UsersNotifier extends AsyncNotifier<List<UserAccountModel>> {
  @override
  Future<List<UserAccountModel>> build() => _load();

  Future<List<UserAccountModel>> _load() async {
    final cache = ref.read(localCacheProvider);
    final connectivity = ref.read(connectivityProvider);

    final cached = cache
        .getJsonList(_cacheKey)
        .map((e) => UserAccountModel.fromJson(e))
        .toList();

    if (!connectivity.isOnline.value) {
      if (cached.isEmpty) {
        throw 'No internet connection. Connect to load users.';
      }
      return cached;
    }

    final resp = await ref.read(supabaseServiceProvider).callEdgeFunction(
          'manage-users',
          body: {},
          method: 'GET',
        );

    if (!resp.success || resp.data == null) {
      if (cached.isNotEmpty) return cached;
      throw resp.message;
    }

    final rows = _extractRows(resp.data);
    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => UserAccountModel.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    final List raw = data is List
        ? data
        : (data is Map ? (data['data'] as List? ?? data['users'] as List? ?? []) : []);
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final usersProvider =
    AsyncNotifierProvider<UsersNotifier, List<UserAccountModel>>(UsersNotifier.new);
