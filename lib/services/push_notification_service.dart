import 'dart:io';

import 'package:chat_app/constants/network_constants.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'background_message_processor.dart';
import 'chat_notification_service.dart';
import 'message_sync_service.dart';
import 'notification_navigation_service.dart';
import 'storage_service.dart';

class PushNotificationService extends GetxService {
  PushNotificationService({
    ApiService? apiService,
    StorageService? storageService,
  }) : _apiService = apiService ?? Get.find<ApiService>(),
       _storageService = storageService ?? Get.find<StorageService>();

  final ApiService _apiService;
  final StorageService _storageService;
  bool _firebaseReady = false;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      Get.log('Firebase is not configured yet: $e', isError: true);
      return;
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }

    if (Get.isRegistered<MessageSyncService>()) {
      await Get.find<MessageSyncService>().syncMissedMessages();
    }
  }

  Future<void> registerCurrentToken() async {
    if (!_firebaseReady) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await BackgroundMessageProcessor.processRemoteMessage(
      message,
      showNotification: _shouldShowForegroundNotification(message),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final data = message.data;
    final isGroup = data['is_group'] == 'true' || data['is_group'] == true;
    if (Get.isRegistered<NotificationNavigationService>()) {
      Get.find<NotificationNavigationService>().openChat({
        'chatId': isGroup ? data['chat_id'] : data['sender_id'],
        'messageId': data['message_id'],
        'senderId': data['sender_id'],
        'senderName': data['sender_name'],
        'chatName': data['chat_name'],
        'isGroup': isGroup,
      });
    }
  }

  bool _shouldShowForegroundNotification(RemoteMessage message) {
    if (!Get.isRegistered<ChatNotificationService>()) return false;
    return !Get.find<ChatNotificationService>().isForeground;
  }

  Future<void> _registerToken(String token) async {
    try {
      await _apiService.dio.post(
        NetworkConstants.devicesRegister,
        data: {
          'deviceId': await _deviceId(),
          'platform': Platform.isAndroid
              ? 'android'
              : Platform.isIOS
              ? 'ios'
              : 'unknown',
          'fcmToken': token,
          'appVersion': '1.0.0+1',
        },
      );
    } catch (e) {
      Get.log('Failed to register FCM token: $e', isError: true);
    }
  }

  Future<String> _deviceId() async {
    var deviceId = _storageService.getString('deviceId');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _storageService.saveString('deviceId', deviceId);
    }
    return deviceId;
  }
}
