import 'package:chat_app/constants/string_constants.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/core/theme/theme_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'features/chats/domain/repositories/chat_repository.dart';
import 'features/calls/presentation/widgets/call_overlay_host.dart';
import 'services/storage_service.dart';
import 'services/connectivity_service.dart';
import 'services/call_service.dart';
import 'services/call_notification_service.dart';
import 'services/call_overlay_service.dart';
import 'services/call_pip_service.dart';
import 'features/calls/presentation/controllers/call_controller.dart';
import 'services/sync_service.dart';
import 'services/socket_service.dart';
import 'core/database/realm_helper.dart';
import 'services/background_message_processor.dart';
import 'services/chat_notification_service.dart';
import 'services/message_sync_service.dart';
import 'services/notification_navigation_service.dart';
import 'services/push_notification_service.dart';
import 'services/receipt_service.dart';
import 'services/session_privacy_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Services
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => ApiService().init());

  // Initialize Database
  RealmHelper().init();

  // Initialize Network & Sync
  Get.put(ConnectivityService());
  Get.put(SocketService());
  Get.put(ChatRepository());
  Get.put(SessionPrivacyService());
  Get.put(ReceiptService());
  Get.put(NotificationNavigationService());
  Get.put(ChatNotificationService());
  await Get.find<ChatNotificationService>().initialize();
  await Get.find<ChatNotificationService>().requestPermissions();
  Get.put(MessageSyncService());
  Get.put(CallService());
  Get.put(CallOverlayService());
  Get.put(CallPipService());
  Get.put(CallNotificationService());
  Get.put(CallController());
  Get.put(SyncService());

  // Initialize ThemeController
  Get.put(ThemeController());
  Get.put(PushNotificationService());
  await Get.find<PushNotificationService>().initialize();

  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (Get.isRegistered<NotificationNavigationService>()) {
      Get.find<NotificationNavigationService>().markReady();
    }
  });
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
      builder: (context, child) {
        return CallOverlayHost(child: child ?? const SizedBox.shrink());
      },
      defaultTransition:
          Transition.rightToLeftWithFade, // Smooth page transitions

      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
