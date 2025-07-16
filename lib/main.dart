// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:stove_transaction/core/constants/app_config.dart';
import 'package:stove_transaction/core/routes/app_pages.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/theme/app_theme.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/admin/sales/controller/sales_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

const supabaseUrl = 'https://oeiwnpngbnkhcismhpgs.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9laXducG5nYm5raGNpc21ocGdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0MDcyMDEsImV4cCI6MjA2Njk4MzIwMX0.Psuchp0nUS2VcKZrFTWPvXkO_JfV1f7QAhynhiZIuy0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: AppConfig.acslSupabaseURL, anonKey: supabaseKey);
  await GetStorage.init();
  await Get.putAsync(() => SessionManager().init());
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
