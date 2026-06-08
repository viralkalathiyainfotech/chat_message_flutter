import 'package:chat_app/constants/color_constants.dart';
import 'package:chat_app/constants/string_constants.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Services
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => ApiService().init());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: StringConstants.appName,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: ColorConstants.backgroundLight,
        colorScheme: const ColorScheme.dark().copyWith(
          primary: ColorConstants.primaryBlue,
          surface: ColorConstants.backgroundLight,
        ),
      ),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      debugShowCheckedModeBanner: false,
    );
  }
}
