/// Riverpod provider layer for core services.
///
/// TRANSITIONAL: during the GetX -> Riverpod migration these providers expose
/// the service singletons already registered in `main.dart` via `Get.find`.
/// As each service is fully ported, swap the body to construct/own the instance
/// here and drop the `Get.find` call. See docs/flutter.md.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart' show Get, Inst;

import 'package:stove_transaction/core/auth/permissions.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
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

/// Current user's role (canonical or legacy string), or null when logged out.
final roleProvider = Provider<String?>((ref) => ref.watch(sessionProvider).role);

/// Resolved permissions for the current role. Drives sidebar visibility and
/// in-screen widget gating. Super admin => every route + feature.
final permissionsProvider = Provider<RolePermissions>(
  (ref) => getRolePermissions(ref.watch(roleProvider)),
);
