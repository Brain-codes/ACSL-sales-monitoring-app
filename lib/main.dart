import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/core/config/env_config.dart';
import 'package:stove_transaction/core/router/app_router.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/location_resolution_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/app_release_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';
import 'package:stove_transaction/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'package:logger/logger.dart';
import 'dart:async';

Future<void> main() async {
  runZonedGuarded(_bootstrap, (error, stack) {
    // Swallow background auth-refresh failures (e.g. invalid/expired refresh
    // token) that Supabase throws off the main call stack, so they can't crash
    // or hang startup. Session cleanup is handled in _restoreSession.
    if (error is AuthException) {
      Logger().w('Uncaught auth error: $error');
      return;
    }
    Logger().e('Uncaught error: $error', error: error, stackTrace: stack);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfig.initialize();

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  await GetStorage.init();
  await Get.putAsync(() => SessionManager().init());

  // Attempt to refresh the saved session on startup
  await _restoreSession();

  Get.put(SupabaseService());
  Get.put(LocalCacheService());
  Get.put(SyncService());
  Get.put(LocationResolutionService());
  await Get.putAsync(() => OfflineQueueService().init());
  await Get.putAsync(() => ConnectivityService().init());
  Get.put(DataRefreshService());
  Get.put(AuthService());
  Get.put(AppReleaseService());

  // Set baseline system UI style before the first frame.
  // Screens with AppBar override via AppBarTheme.systemOverlayStyle.
  // Login/splash override via AnnotatedRegion.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const ProviderScope(child: AcslSalesApp()));
}

Future<void> _restoreSession() async {
  final session = Get.find<SessionManager>();
  final saved = session.getSupabaseSession();
  if (saved?.refreshToken == null) return;
  try {
    final result = await Supabase.instance.client.auth.refreshSession(saved!.refreshToken!);
    if (result.session != null) {
      session.saveSupabaseSession(result.session);
      session.setToken(result.session!.accessToken);
    }
  } on AuthApiException catch (e) {
    // OFFLINE-FIRST: only a genuine server rejection of the refresh token
    // (revoked / truly expired) means we must re-authenticate. In that case
    // purge Supabase's own persisted session too, otherwise its background
    // auto-refresh keeps retrying the dead token on every launch.
    Logger().w('Session restore rejected by server: $e');
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    session.logout();
  } catch (e) {
    // Network/offline/transient failure — DO NOT log out. Keep the stored
    // session so the user stays signed in and can work fully offline; the
    // token is refreshed automatically once connectivity returns.
    Logger().w('Session restore deferred (offline/transient): $e');
  }
}

class AcslSalesApp extends ConsumerWidget {
  const AcslSalesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'ACSL Sales',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
