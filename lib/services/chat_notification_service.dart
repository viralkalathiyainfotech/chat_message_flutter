import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'background_message_processor.dart';
import 'notification_navigation_service.dart';
import 'receipt_service.dart';

@pragma('vm:entry-point')
void chatNotificationBackgroundHandler(NotificationResponse response) {
  BackgroundMessageProcessor.handleNotificationAction(
    actionId: response.actionId,
    input: response.input,
    payload: response.payload,
  );
}

class ChatNotificationService extends GetxService with WidgetsBindingObserver {
  static const String channelId = 'chat_messages';
  static const String replyActionId = 'reply';
  static const String markReadActionId = 'mark_read';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isForeground = true;

  bool get isForeground => _isForeground;

  Future<void> initialize() async {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(this);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'chat_message',
          actions: [
            DarwinNotificationAction.text(
              replyActionId,
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Message',
            ),
            DarwinNotificationAction.plain(markReadActionId, 'Mark read'),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: darwin, macOS: darwin),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse:
          chatNotificationBackgroundHandler,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showChatMessageNotification({
    required String chatId,
    required String messageId,
    required String senderName,
    required String preview,
    required bool isGroup,
    String? chatName,
    String? senderId,
  }) async {
    await initialize();

    final payload = jsonEncode({
      'chatId': chatId,
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'chatName': chatName,
      'isGroup': isGroup,
    });
    final title = isGroup && chatName != null ? '$chatName: $senderName' : senderName;
    final notificationId = messageId.hashCode & 0x7fffffff;

    const replyInput = AndroidNotificationActionInput(label: 'Message');
    final android = AndroidNotificationDetails(
      channelId,
      'Chat messages',
      channelDescription: 'Incoming chat message notifications',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      groupKey: 'chat_$chatId',
      actions: const [
        AndroidNotificationAction(
          replyActionId,
          'Reply',
          inputs: [replyInput],
          allowGeneratedReplies: true,
          semanticAction: SemanticAction.reply,
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          markReadActionId,
          'Mark read',
          semanticAction: SemanticAction.markAsRead,
          showsUserInterface: false,
        ),
      ],
    );

    const darwin = DarwinNotificationDetails(categoryIdentifier: 'chat_message');

    await _plugin.show(
      notificationId,
      title,
      preview.isEmpty ? 'New message' : preview,
      NotificationDetails(android: android, iOS: darwin, macOS: darwin),
      payload: payload,
    );
  }

  Future<void> cancelChatNotification(String messageId) async {
    await _plugin.cancel(messageId.hashCode & 0x7fffffff);
  }

  void _handleResponse(NotificationResponse response) {
    if (response.actionId == replyActionId) {
      BackgroundMessageProcessor.handleNotificationAction(
        actionId: response.actionId,
        input: response.input,
        payload: response.payload,
      );
      return;
    }

    if (response.actionId == markReadActionId) {
      _markPayloadRead(response.payload);
      return;
    }

    if (Get.isRegistered<NotificationNavigationService>()) {
      Get.find<NotificationNavigationService>().openChatFromPayload(
        response.payload,
      );
    }
  }

  Future<void> _markPayloadRead(String? payload) async {
    if (payload == null || !Get.isRegistered<ReceiptService>()) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final chatId = decoded['chatId']?.toString();
      final messageId = decoded['messageId']?.toString();
      if (chatId == null || messageId == null) return;
      await Get.find<ReceiptService>().markRead(
        chatId: chatId,
        messageIds: [messageId],
      );
      await cancelChatNotification(messageId);
    } catch (e) {
      Get.log('Failed to mark notification as read: $e', isError: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
