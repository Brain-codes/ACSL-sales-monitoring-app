import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/core/config/env_config.dart';
import 'package:stove_transaction/core/routes/app_pages.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/services/app_release_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';
import 'package:stove_transaction/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'package:logger/logger.dart';

Future<void> main() async {
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

  runApp(const AcslSalesApp());
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
  } catch (e) {
    Logger().w('Session restore failed: $e');
    session.logout();
  }
}

class AcslSalesApp extends StatelessWidget {
  const AcslSalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    final String initial;
    if (!session.isAuthenticated) {
      initial = AppRoutes.splash;
    } else if (session.isAcslAgent || session.isAdmin || session.isAcslAgentManager) {
      initial = AppRoutes.acslHome;
    } else if (session.isPartnerAgent) {
      initial = AppRoutes.partnerHome;
    } else {
      initial = AppRoutes.splash;
    }

    return ToastificationWrapper(
      child: GetMaterialApp(
        title: 'ACSL Sales',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: initial,
        getPages: AppPages.routes,
      ),
    );
  }
}
