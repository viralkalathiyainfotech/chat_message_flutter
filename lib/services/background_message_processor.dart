import 'dart:convert';
import 'dart:ui';

import 'package:chat_app/constants/network_constants.dart';
import 'package:chat_app/core/database/realm_helper.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:chat_app/features/chats/domain/repositories/chat_repository.dart';
import 'package:chat_app/utils/encryption_util.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'chat_notification_service.dart';
import 'connectivity_service.dart';
import 'receipt_service.dart';
import 'socket_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await BackgroundMessageProcessor.processRemoteMessage(
    message,
    showNotification: true,
  );
}

class BackgroundMessageProcessor {
  static Future<void> processRemoteMessage(
    RemoteMessage message, {
    required bool showNotification,
  }) async {
    await ensureBackgroundServices();
    
    final data = message.data;
    if ((data['type'] ?? data['message_type']) != 'chat_message') return;

    final payload = await _messagePayload(data);
    if (payload == null) return;

    final messageId = _id(payload['_id'] ?? payload['messageId'] ?? data['message_id']);
    if (messageId == null) return;

    await Get.find<ChatRepository>().saveIncomingMessage(payload);
    await Get.find<ReceiptService>().markDelivered([messageId]);

    if (showNotification) {
      await _showNotification(payload, data);
    }
  }

  static Future<void> handleNotificationAction({
    required String? actionId,
    required String? payload,
    required String? input,
  }) async {
    await ensureBackgroundServices();

    String? messageId;
    String? chatId;
    try {
      if (payload == null || payload.isEmpty) {
        await _recordActionTrace(actionId, 'missing_payload');
        return;
      }

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      chatId = _actionChatId(decoded);
      messageId = decoded['messageId']?.toString();
      await _recordActionTrace(actionId, 'received', extra: {
        'chatId': chatId,
        'messageId': messageId,
        'hasInput': input?.trim().isNotEmpty == true,
      });

      if (chatId == null || chatId.isEmpty || messageId == null) {
        await _recordActionTrace(actionId, 'invalid_payload');
        return;
      }

      await _cancelActionNotification(messageId);

      if (actionId == ChatNotificationService.replyActionId) {
        final replyText = input?.trim();
        if (replyText == null || replyText.isEmpty) {
          await _recordActionTrace(actionId, 'empty_reply');
          return;
        }

        await _sendNotificationReply(chatId, replyText);
        await _recordActionTrace(actionId, 'reply_sent', extra: {
          'chatId': chatId,
          'messageId': messageId,
        });
        return;
      }

      if (actionId == ChatNotificationService.markReadActionId) {
        await Get.find<ReceiptService>().markRead(
          chatId: chatId,
          messageIds: [messageId],
        );
        RealmHelper().updateMessageStatus(messageId, 'read');
        await _recordActionTrace(actionId, 'marked_read', extra: {
          'chatId': chatId,
          'messageId': messageId,
        });
      }
    } catch (e) {
      await _recordActionTrace(actionId, 'failed', extra: {
        'chatId': chatId,
        'messageId': messageId,
        'error': e.toString(),
      });
      Get.log('Failed to handle notification action: $e', isError: true);
    } finally {
      await _cancelActionNotification(messageId);
    }
  }

  static Future<void> ensureBackgroundServices() async {
    if (!Get.isRegistered<StorageService>()) {
      await Get.putAsync(() => StorageService().init());
    }
    if (!Get.isRegistered<ApiService>()) {
      await Get.putAsync(() => ApiService().init());
    }
    if (!RealmHelper().isInitialized) {
      RealmHelper().init();
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put(ConnectivityService());
    }
    if (!Get.isRegistered<SocketService>()) {
      Get.put(SocketService());
    }
    if (!Get.isRegistered<ChatRepository>()) {
      Get.put(ChatRepository());
    }
    if (!Get.isRegistered<ReceiptService>()) {
      Get.put(ReceiptService());
    }
    if (!Get.isRegistered<ChatNotificationService>()) {
      Get.put(ChatNotificationService());
      await Get.find<ChatNotificationService>().initialize();
    }
  }

  static Future<Map<String, dynamic>?> _messagePayload(
    Map<String, dynamic> data,
  ) async {
    final messageId = _id(data['message_id'] ?? data['messageId']);
    if (messageId == null) return null;

    try {
      final response = await Get.find<ApiService>().dio.get(
        NetworkConstants.messageById(messageId),
      );
      final message = response.data['message'] ?? response.data['data'];
      if (message is Map<String, dynamic>) return message;
      if (message is Map) {
        return message.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (e) {
      Get.log('Could not fetch pushed message $messageId: $e', isError: true);
    }

    return {
      '_id': messageId,
      'messageId': messageId,
      'senderId': data['sender_id'],
      'receiverId': data['receiver_id'],
      'groupId': data['is_group'] == 'true' ? data['chat_id'] : null,
      'content': {
        'type': data['message_type'] ?? 'text',
        'content': data['preview'] ?? '',
      },
      'status': 'delivered',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Future<void> _showNotification(
    Map<String, dynamic> payload,
    Map<String, dynamic> data,
  ) async {
    final messageId = _id(payload['_id'] ?? data['message_id']);
    final chatId = _notificationChatId(payload, data);
    if (messageId == null || chatId == null) return;

    final content = payload['content'];
    final encryptedPreview = content is Map
        ? (content['content']?.toString() ?? data['preview']?.toString() ?? '')
        : data['preview']?.toString() ?? '';
    final preview = _notificationPreview(
      encryptedPreview,
      messageType: data['message_type']?.toString(),
    );

    await Get.find<ChatNotificationService>().showChatMessageNotification(
      chatId: chatId,
      messageId: messageId,
      senderName: data['sender_name']?.toString() ?? 'New message',
      preview: preview,
      isGroup: data['is_group'] == 'true' || data['is_group'] == true,
      chatName: data['chat_name']?.toString(),
      senderId: data['sender_id']?.toString(),
    );
  }

  static Future<void> _sendNotificationReply(
    String chatId,
    String replyText,
  ) async {
    final encrypted = EncryptionUtil.encrypt(replyText);
    final response = await Get.find<ApiService>().dio.post(
      NetworkConstants.replyFromNotification,
      data: {
        'chatId': chatId,
        'replyText': encrypted,
        'clientMessageId': const Uuid().v4(),
        'deviceId': await _deviceId(),
      },
    );

    final message = response.data is Map
        ? (response.data['data'] ?? response.data['message'])
        : null;
    if (message is Map<String, dynamic>) {
      await Get.find<ChatRepository>().saveIncomingMessage({
        ...message,
        'isFromNotification': true,
        'isSynced': true,
      });
      return;
    }
    if (message is Map) {
      await Get.find<ChatRepository>().saveIncomingMessage({
        ...message.map((key, value) => MapEntry(key.toString(), value)),
        'isFromNotification': true,
        'isSynced': true,
      });
    }
  }

  static Future<String> _deviceId() async {
    final storage = Get.find<StorageService>();
    var deviceId = storage.getString('deviceId');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await storage.saveString('deviceId', deviceId);
    }
    return deviceId;
  }

  static Future<void> _cancelActionNotification(String? messageId) async {
    if (messageId == null || !Get.isRegistered<ChatNotificationService>()) {
      return;
    }

    await Get.find<ChatNotificationService>().cancelChatNotification(messageId);
  }

  static Future<void> _recordActionTrace(
    String? actionId,
    String stage, {
    Map<String, dynamic>? extra,
  }) async {
    if (!Get.isRegistered<StorageService>()) return;
    await Get.find<StorageService>().saveString(
      'last_notification_action_trace',
      jsonEncode({
        'actionId': actionId,
        'stage': stage,
        'at': DateTime.now().toUtc().toIso8601String(),
        if (extra != null) ...extra,
      }),
    );
  }

  static String? _id(dynamic value) {
    if (value == null) return null;
    if (value is Map) return (value['_id'] ?? value['id'])?.toString();
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static String? _notificationChatId(
    Map<String, dynamic> payload,
    Map<String, dynamic> data,
  ) {
    final isGroup = data['is_group'] == 'true' ||
        data['is_group'] == true ||
        payload['groupId'] != null ||
        payload['group'] != null;

    if (isGroup) {
      return _id(payload['groupId'] ?? payload['group'] ?? data['chat_id']);
    }

    return _id(payload['senderId'] ?? payload['sender'] ?? data['sender_id']) ??
        _id(data['chat_id']);
  }

  static String? _actionChatId(Map<String, dynamic> payload) {
    final isGroup = payload['isGroup'] == true || payload['is_group'] == 'true';
    if (isGroup) {
      return _id(payload['chatId'] ?? payload['chat_id']);
    }

    return _id(payload['senderId'] ?? payload['sender_id']) ??
        _id(payload['chatId'] ?? payload['chat_id']);
  }

  static String _notificationPreview(String preview, {String? messageType}) {
    if (messageType == 'file') return preview.isEmpty ? 'Attachment' : preview;
    if (messageType == 'call') return 'Call';
    if (messageType == 'system') return EncryptionUtil.decrypt(preview);
    return EncryptionUtil.decrypt(preview);
  }
}
