import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stove_transaction/core/providers/services.dart';
import 'package:stove_transaction/core/services/paged_fetch.dart';
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

    // M10: fetched one capped page and showed it as every user.
    List<Map<String, dynamic>> rows;
    try {
      rows = await fetchAllPages(
        ref.read(supabaseServiceProvider),
        'manage-users',
        pageSize: 100,
        errorMessage: 'Could not load users',
      );
    } catch (e) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
    cache.saveJsonList(_cacheKey, rows);
    return rows.map((e) => UserAccountModel.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

}

final usersProvider =
    AsyncNotifierProvider<UsersNotifier, List<UserAccountModel>>(UsersNotifier.new);
