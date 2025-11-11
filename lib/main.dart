// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/core/config/env_config.dart';
import 'package:stove_transaction/core/routes/app_pages.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/supabase_service.dart';
import 'package:stove_transaction/core/theme/app_theme.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/offline_storage_service.dart';
import 'package:stove_transaction/core/services/offline_sync_service.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'package:logger/logger.dart';

/// Restore Supabase session from storage
Future<void> _restoreSupabaseSession() async {
  try {
    final sessionManager = Get.find<SessionManager>();
    final savedSession = sessionManager.getSupabaseSession();
    final logger = Logger();

    if (savedSession != null) {
      logger.d('Restoring Supabase session from storage...');

      // Check if the session is still valid
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = savedSession.expiresAt ?? 0;

      if (expiresAt > now + 300) {
        // Give 5 minutes buffer
        // Session is still valid, restore it
        try {
          // Try to set the session manually
          if (savedSession.refreshToken != null) {
            final response = await Supabase.instance.client.auth
                .refreshSession(savedSession.refreshToken!);
            if (response.session != null) {
              sessionManager.saveSupabaseSession(response.session);
              logger.d('Session restored via refresh');
            } else {
              throw Exception('Failed to restore session');
            }
          } else {
            throw Exception('No refresh token available');
          }
        } catch (e) {
          logger.e('Failed to recover session: $e');
          // Try to refresh instead
          await _attemptSessionRefresh(savedSession, sessionManager, logger);
        }
      } else {
        // Session expired or about to expire, try to refresh
        logger.d('Session expired or about to expire, attempting refresh...');
        await _attemptSessionRefresh(savedSession, sessionManager, logger);
      }
    } else {
      logger.d('No saved session found');
    }
  } catch (e) {
    Logger().e('Error restoring session: $e');
  }
}

/// Attempt to refresh session with proper error handling
Future<void> _attemptSessionRefresh(
    Session savedSession, SessionManager sessionManager, Logger logger) async {
  if (savedSession.refreshToken != null &&
      savedSession.refreshToken!.isNotEmpty) {
    try {
      logger.d('Attempting to refresh session...');
      final response = await Supabase.instance.client.auth
          .refreshSession(savedSession.refreshToken!);

      if (response.session != null &&
          response.session!.accessToken.isNotEmpty) {
        // Save the new session
        sessionManager.saveSupabaseSession(response.session);
        sessionManager.setToken(response.session!.accessToken);
        logger.d('Session refreshed successfully');
      } else {
        logger.e('Failed to refresh session: No valid session returned');
        sessionManager.logout();
      }
    } catch (e) {
      logger.e('Failed to refresh session: $e');

      // Check if it's a refresh token error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('refresh_token_not_found') ||
          errorString.contains('invalid refresh token') ||
          errorString.contains('refresh token not found') ||
          errorString.contains('session_not_found')) {
        logger.e('Invalid refresh token detected, clearing session');
        sessionManager.logout();
      }
    }
  } else {
    logger.e('No refresh token available');
    sessionManager.logout();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await EnvConfig.initialize();

  // Verify environment variables are loaded
  if (!EnvConfig.isConfigured) {
    throw Exception(
        'Environment variables are not properly configured. Please check your .env file.');
  }

  await Supabase.initialize(
      url: EnvConfig.supabaseUrl, anonKey: EnvConfig.supabaseAnonKey);
  await GetStorage.init();
  await Get.putAsync(() => SessionManager().init());

  // Restore Supabase session if available
  await _restoreSupabaseSession();

  // Initialize core services
  Get.put(SupabaseService());

  // Initialize offline services
  await Get.putAsync(() => OfflineStorageService().init());
  Get.put(OfflineSyncService());

  Get.put(AuthService());
  Get.put(SalesController()); // Add this line
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Color.fromARGB(0, 14, 124, 188),
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    return ToastificationWrapper(
      child: GetMaterialApp(
        title: 'Sales Monitoring App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, // Or ThemeMode.light/dark
        initialRoute: Get.find<SessionManager>().token != null
            ? (Get.find<SessionManager>().isAdmin
                ? AppRoutes.ADMIN_HOME
                : AppRoutes.AGENT_HOME)
            : AppRoutes.SPLASH,
        getPages: AppPages.routes,
      ),
    );
  }
}
