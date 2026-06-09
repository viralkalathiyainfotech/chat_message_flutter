import 'package:chat_app/constants/string_constants.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'services/storage_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/socket_service.dart';
import 'core/database/realm_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Services
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => ApiService().init());
  
  // Initialize Database
  RealmHelper().init();
  
  // Initialize Network & Sync
  Get.put(ConnectivityService());
  Get.put(SocketService());
  Get.put(SyncService());
  
  // Initialize ThemeController
  Get.put(ThemeController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    
    return GetMaterialApp(
      title: StringConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.rightToLeftWithFade, // Smooth page transitions

      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
