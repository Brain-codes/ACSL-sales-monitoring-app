/// Riverpod provider layer for core services.
///
/// TRANSITIONAL: during the GetX -> Riverpod migration these providers expose
/// the service singletons already registered in `main.dart` via `Get.find`.
/// As each service is fully ported, swap the body to construct/own the instance
/// here and drop the `Get.find` call. See docs/flutter.md.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart' show Get, Inst;

import 'package:stove_transaction/core/model/sale_field_dictionary.dart';
import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/sale_dictionary_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';

/// Centralized edge-function client. Feature code calls
/// `ref.read(supabaseServiceProvider).callEdgeFunction(...)` — never `Supabase.from`.
final supabaseServiceProvider =
    Provider<SupabaseService>((ref) => Get.find<SupabaseService>());

final sessionProvider =
    Provider<SessionManager>((ref) => Get.find<SessionManager>());

final localCacheProvider =
    Provider<LocalCacheService>((ref) => Get.find<LocalCacheService>());

final offlineQueueProvider =
    Provider<OfflineQueueService>((ref) => Get.find<OfflineQueueService>());

final syncServiceProvider =
    Provider<SyncService>((ref) => Get.find<SyncService>());

final connectivityProvider =
    Provider<ConnectivityService>((ref) => Get.find<ConnectivityService>());

/// Bumps whenever the signed-in identity changes (login, logout, role change).
///
/// The role lives in GetStorage, which is not reactive, and [sessionProvider]
/// hands back the same [SessionManager] instance forever. Without this, a plain
/// `Provider` reading `.role` computed ONCE — on the splash screen, before
/// anyone had signed in — resolved to null, and never recomputed. Every role,
/// super admin included, was then bounced to /unauthorized after logging in.
///
/// [SessionManager.revision] ticks on every identity write; this provider
/// invalidates itself when it does, so everything downstream recomputes.
final sessionRevisionProvider = Provider<int>((ref) {
  final session = ref.watch(sessionProvider);
  void onChanged() => ref.invalidateSelf();
  session.revision.addListener(onChanged);
  ref.onDispose(() => session.revision.removeListener(onChanged));
  return session.revision.value;
});

/// Current user's role (canonical or legacy string), or null when logged out.
final roleProvider = Provider<String?>((ref) {
  ref.watch(sessionRevisionProvider);
  return ref.read(sessionProvider).role;
});

/// Resolved permissions for the current role. Drives sidebar visibility and
/// in-screen widget gating. Super admin => every route + feature.
final permissionsProvider = Provider<RolePermissions>(
  (ref) => getRolePermissions(ref.watch(roleProvider)),
);

/// The sale field dictionary service.
final saleDictionaryServiceProvider = Provider<SaleDictionaryService>(
  (ref) => Get.find<SaleDictionaryService>(),
);

/// The sale field dictionary currently in force.
///
/// Resolves from the offline cache or the bundled seed immediately, then
/// revalidates against the endpoint with `If-None-Match`. Widgets read labels,
/// options and required-ness from here so none of the three is typed into the
/// app. A failed refresh keeps the previous copy, so this stays usable offline.
final saleDictionaryProvider = FutureProvider<SaleFieldDictionary?>((ref) async {
  final service = ref.watch(saleDictionaryServiceProvider);
  await service.ensureLoaded();
  return service.refresh();
});
