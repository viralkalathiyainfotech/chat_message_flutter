import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'background_message_processor.dart';
import 'notification_navigation_service.dart';

@pragma('vm:entry-point')
void chatNotificationBackgroundHandler(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  unawaited(
    BackgroundMessageProcessor.handleNotificationAction(
      actionId: response.actionId,
      input: response.input,
      payload: response.payload,
    ),
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

  // Cache to retain incoming messages in memory per chat session.
  // Format: { chatId: [Message, Message, ...] }
  final Map<String, List<Message>> _chatHistoryCache = {};

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
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              markReadActionId,
              'Mark read',
              options: {DarwinNotificationActionOption.foreground},
            ),
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
          AndroidFlutterLocalNotificationsPlugin
        >()
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

    // 1. Group notifications by chat instead of sender
    final notificationId = chatId.hashCode & 0x7fffffff;
    final String currentText = preview.isEmpty ? 'New message' : preview;

    // 2. Build or fetch historical message thread
    if (!_chatHistoryCache.containsKey(chatId)) {
      _chatHistoryCache[chatId] = [];
    }
    
    final person = Person(
      key: senderId ?? senderName,
      name: senderName,
    );

    // Append the newly arrived message to the thread
    _chatHistoryCache[chatId]!.add(
      Message(
        currentText,
        DateTime.now(),
        person,
      ),
    );

    // Limit cache sizes to the last 20 messages to prevent memory bloating
    if (_chatHistoryCache[chatId]!.length > 20) {
      _chatHistoryCache[chatId]!.removeAt(0);
    }

    // 3. Assemble native Android Conversation Style
    final messagingStyle = MessagingStyleInformation(
      Person(
        key: 'current_user', 
        name: 'Me', // App recipient persona
      ),
      conversationTitle: isGroup ? chatName : null,
      groupConversation: isGroup,
      messages: _chatHistoryCache[chatId]!,
    );

    const replyInput = AndroidNotificationActionInput(label: 'Message');
    final android = AndroidNotificationDetails(
      channelId,
      'Chat messages',
      channelDescription: 'Incoming chat message notifications',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: messagingStyle, // Inject style here
      onlyAlertOnce: false, // Ensures audio alerts play on new subsequent texts
      groupKey: 'chat_global_group', // Native Android summary bundling
      actions: const [
        AndroidNotificationAction(
          replyActionId,
          'Reply',
          inputs: [replyInput],
          allowGeneratedReplies: true,
          semanticAction: SemanticAction.reply,
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          markReadActionId,
          'Mark as read',
          semanticAction: SemanticAction.markAsRead,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const darwin = DarwinNotificationDetails(
      categoryIdentifier: 'chat_message',
      // Note: On iOS, system stack bundling automatically manages subsequent 
      // messages when notificationId/threadIdentifier is consistent.
    );

    // Determine the visible fallback summary text titles
    final collapsedTitle = isGroup && chatName != null ? chatName : senderName;

    await _plugin.show(
      notificationId,
      collapsedTitle,
      currentText,
      NotificationDetails(android: android, iOS: darwin, macOS: darwin),
      payload: payload,
    );
  }

  // Clear tracking records when a chat context is dismissed or read
  Future<void> cancelChatNotification(String chatId) async {
    _chatHistoryCache.remove(chatId);
    await _plugin.cancel(chatId.hashCode & 0x7fffffff);
  }

  void _handleResponse(NotificationResponse response) {
    unawaited(_handleResponseAsync(response));
  }

  Future<void> _handleResponseAsync(NotificationResponse response) async {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        if (data['chatId'] != null) {
          // Clear active notifications and cache once user engages
          await cancelChatNotification(data['chatId']);
        }
      } catch (_) {}
    }

    if (response.actionId == replyActionId ||
        response.actionId == markReadActionId) {
      await BackgroundMessageProcessor.handleNotificationAction(
        actionId: response.actionId,
        input: response.input,
        payload: response.payload,
      );
      return;
    }

    if (Get.isRegistered<NotificationNavigationService>()) {
      Get.find<NotificationNavigationService>().openChatFromPayload(
        response.payload,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
  }

  @override
  void onClose() {
    _chatHistoryCache.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
