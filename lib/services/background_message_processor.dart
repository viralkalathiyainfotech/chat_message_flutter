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
    if (payload == null || payload.isEmpty) return;
    await ensureBackgroundServices();

    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    final chatId = decoded['chatId']?.toString();
    final messageId = decoded['messageId']?.toString();

    if (actionId == ChatNotificationService.replyActionId &&
        chatId != null &&
        input != null &&
        input.trim().isNotEmpty) {
      await _sendNotificationReply(chatId, input.trim());
      return;
    }

    if (actionId == ChatNotificationService.markReadActionId &&
        chatId != null &&
        messageId != null) {
      await Get.find<ReceiptService>().markRead(
        chatId: chatId,
        messageIds: [messageId],
      );
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
      'receiverId': data['is_group'] == 'true' ? data['chat_id'] : null,
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
    final chatId = _id(payload['groupId'] ?? payload['group'] ?? data['chat_id']) ??
        _id(payload['senderId'] ?? payload['sender'] ?? data['sender_id']);
    if (messageId == null || chatId == null) return;

    final content = payload['content'];
    final preview = content is Map
        ? (content['content']?.toString() ?? data['preview']?.toString() ?? '')
        : data['preview']?.toString() ?? '';

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
    await Get.find<ApiService>().dio.post(
      NetworkConstants.replyFromNotification,
      data: {
        'chatId': chatId,
        'replyText': encrypted,
        'clientMessageId': const Uuid().v4(),
        'deviceId': Get.find<StorageService>().getString('deviceId'),
      },
    );
  }

  static String? _id(dynamic value) {
    if (value == null) return null;
    if (value is Map) return (value['_id'] ?? value['id'])?.toString();
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
