import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'background_message_processor.dart';
import '../features/calls/presentation/controllers/call_controller.dart';
import 'call_service.dart';
import 'notification_navigation_service.dart';

@pragma('vm:entry-point')
void chatNotificationBackgroundHandler(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (ChatNotificationService.isCallNotificationPayload(response.payload)) {
    return;
  }
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
  static const String incomingCallChannelId = 'incoming_calls_full_screen';
  static const String replyActionId = 'reply';
  static const String markReadActionId = 'mark_read';
  static const String answerCallActionId = 'answer_call';
  static const String declineCallActionId = 'decline_call';
  static const int incomingCallNotificationId = 2102;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isForeground = true;
  bool _handledInitialLaunch = false;

  // Cache to retain incoming messages in memory per chat session.
  // Format: { chatId: [Message, Message, ...] }
  final Map<String, List<Message>> _chatHistoryCache = {};

  bool get isForeground => _isForeground;

  static bool isCallNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map && decoded['notification_kind'] == 'incoming_call';
    } catch (_) {
      return false;
    }
  }

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

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> handleInitialNotificationLaunch() async {
    if (_handledInitialLaunch) return;
    _handledInitialLaunch = true;
    await initialize();

    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp == true && response != null) {
      await _handleResponseAsync(response);
    }
  }

  Future<bool> hasInitialCallNotificationLaunch() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    return details?.didNotificationLaunchApp == true &&
        isCallNotificationPayload(response?.payload);
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

    final person = Person(key: senderId ?? senderName, name: senderName);

    // Append the newly arrived message to the thread
    _chatHistoryCache[chatId]!.add(
      Message(currentText, DateTime.now(), person),
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
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          markReadActionId,
          'Mark as read',
          semanticAction: SemanticAction.markAsRead,
          showsUserInterface: false,
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

  Future<void> showIncomingCallNotificationFromPush(
    Map<String, dynamic> data,
  ) async {
    await initialize();

    final isVideo = _callMediaType(data) == 'video';
    final callerName = _callerName(data);
    final title = isVideo ? 'Incoming video call' : 'Incoming voice call';
    final payload = jsonEncode({
      'notification_kind': 'incoming_call',
      ...data.map((key, value) => MapEntry(key, _payloadValue(value))),
    });

    final android = AndroidNotificationDetails(
      incomingCallChannelId,
      'Incoming calls',
      channelDescription: 'Full-screen incoming call alerts',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 900, 350, 900]),
      actions: const [
        AndroidNotificationAction(
          declineCallActionId,
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          answerCallActionId,
          'Answer',
          showsUserInterface: true,
          semanticAction: SemanticAction.call,
          cancelNotification: true,
        ),
      ],
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    await _plugin.show(
      incomingCallNotificationId,
      title,
      callerName,
      NotificationDetails(android: android, iOS: darwin, macOS: darwin),
      payload: payload,
    );
  }

  // Clear tracking records when a chat context is dismissed or read
  Future<void> cancelChatNotification(String chatId) async {
    _chatHistoryCache.remove(chatId);
    await _plugin.cancel(chatId.hashCode & 0x7fffffff);
  }

  Future<void> cancelIncomingCallNotification() async {
    await _plugin.cancel(incomingCallNotificationId);
  }

  void _handleResponse(NotificationResponse response) {
    unawaited(_handleResponseAsync(response));
  }

  Future<void> _handleResponseAsync(NotificationResponse response) async {
    if (isCallNotificationPayload(response.payload)) {
      await _handleCallNotificationResponse(response);
      return;
    }

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

  Future<void> _handleCallNotificationResponse(
    NotificationResponse response,
  ) async {
    await cancelIncomingCallNotification();
    if (response.payload == null || response.payload!.isEmpty) return;

    final decoded = jsonDecode(response.payload!) as Map<String, dynamic>;
    if (!Get.isRegistered<CallService>()) return;

    final callService = Get.find<CallService>();
    final didRestore = callService.restoreIncomingCallFromPush(decoded);
    if (!didRestore || !Get.isRegistered<CallController>()) return;

    final controller = Get.find<CallController>();
    if (response.actionId == declineCallActionId) {
      controller.declineIncomingCall();
      return;
    }
    if (response.actionId == answerCallActionId) {
      await controller.answerIncomingCall();
      return;
    }
    controller.openIncomingCallScreen();
  }

  String _callerName(Map<String, dynamic> data) {
    return (data['callerName'] ??
            data['caller_name'] ??
            data['fromName'] ??
            data['sender_name'] ??
            data['senderName'] ??
            data['chat_name'] ??
            data['groupName'] ??
            data['fromEmail'] ??
            'Unknown caller')
        .toString();
  }

  String _callMediaType(Map<String, dynamic> data) {
    final value = (data['callType'] ??
            data['call_type'] ??
            data['mediaType'] ??
            data['media_type'] ??
            data['type'])
        ?.toString()
        .toLowerCase();
    if (value == 'audio' || value == 'voice') return 'audio';
    return 'video';
  }

  String _payloadValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
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
