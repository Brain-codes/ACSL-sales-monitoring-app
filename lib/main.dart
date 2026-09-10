import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/core/config/env_config.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/router/app_router.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/geo_data_service.dart';
import 'package:stove_transaction/core/services/sale_dictionary_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/location_resolution_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/permission_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/app_release_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';
import 'package:stove_transaction/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

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

  _installErrorHandlers();

  // Startup MUST always reach runApp(). Previously any throw in here (SQLite
  // open failure, GetStorage, Supabase init) escaped to runZonedGuarded, which
  // logs but cannot recover — runApp never ran and the user was left staring at
  // a permanently blank white screen with no way forward but a reinstall.
  try {
    await _initServices();
  } catch (e, st) {
    Logger().e('Startup failed', error: e, stackTrace: st);
    // Show an explicit, actionable failure instead of a white void.
    runApp(_StartupFailureApp(error: e.toString()));
    return;
  }

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

/// All service registration, in dependency order. Extracted so [_bootstrap] can
/// wrap it in a single guard and still guarantee a `runApp`.
Future<void> _initServices() async {
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
  Get.put(SaleDictionaryService());
  Get.put(GeoDataService());
  Get.put(SyncService());
  Get.put(LocationResolutionService());
  await Get.putAsync(() => OfflineQueueService().init());
  await Get.putAsync(() => ConnectivityService().init());
  Get.put(DataRefreshService());
  Get.put(AuthService());
  Get.put(AppReleaseService());
  Get.put(PermissionService());
}

/// Framework-level error plumbing.
///
/// Without these, a widget that throws during build renders Flutter's default
/// error box — a bare grey/white rectangle in release — which reads to a field
/// user as "the app went blank". These route every error to the logger and put
/// a readable placeholder on screen instead.
void _installErrorHandlers() {
  final logger = Logger();

  // Build/layout/paint errors.
  FlutterError.onError = (details) {
    logger.e('Flutter error: ${details.exceptionAsString()}',
        error: details.exception, stackTrace: details.stack);
    FlutterError.presentError(details);
  };

  // Uncaught async errors that never reach the guarded zone. Returning true
  // marks them handled so the engine doesn't tear the app down.
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Uncaught platform error: $error', error: error, stackTrace: stack);
    return true;
  };

  // Replace the default grey/white error rectangle with something that tells
  // the user what happened and keeps the rest of the screen usable.
  // Directionality/Material are supplied explicitly: this widget can be built
  // ABOVE MaterialApp (e.g. an error during app construction), where Text would
  // otherwise throw for a missing Directionality — an error inside the error
  // handler loops forever.
  ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: AppColors.cardBg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 32),
                SizedBox(height: 8),
                Text(
                  'Something did not display correctly.\nPlease go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Last-resort UI when startup itself failed — strictly better than a blank
/// white screen, and tells the user the one thing that might help.
class _StartupFailureApp extends StatelessWidget {
  final String error;
  const _StartupFailureApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'The app could not start',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please close the app completely and open it again. '
                  'If this keeps happening, contact support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
