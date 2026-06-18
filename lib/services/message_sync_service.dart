import 'package:chat_app/constants/network_constants.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:chat_app/features/chats/domain/repositories/chat_repository.dart';
import 'package:get/get.dart';

import 'chat_notification_service.dart';
import 'receipt_service.dart';
import 'storage_service.dart';

class MessageSyncService extends GetxService {
  MessageSyncService({
    ChatRepository? chatRepository,
    ReceiptService? receiptService,
    StorageService? storageService,
  })  : _chatRepository = chatRepository ?? Get.find<ChatRepository>(),
        _receiptService = receiptService ?? Get.find<ReceiptService>(),
        _storageService = storageService ?? Get.find<StorageService>();

  final ChatRepository _chatRepository;
  final ReceiptService _receiptService;
  final StorageService _storageService;
  bool _isSyncing = false;

  static const String _lastEventKey = 'last_synced_message_event_id';

  Future<void> syncMissedMessages({bool showNotifications = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _receiptService.flushPendingDelivered();

      var afterEventId = int.tryParse(_storageService.getString(_lastEventKey) ?? '0') ?? 0;
      var hasMore = true;

      while (hasMore) {
        final response = await Get.find<ApiService>().dio.get(
          NetworkConstants.messagesSync,
          queryParameters: {
            'afterEventId': afterEventId,
            'limit': 100,
          },
        );

        final events = response.data['events'];
        if (events is! List || events.isEmpty) {
          hasMore = false;
          break;
        }

        final deliveredIds = <String>[];
        for (final rawEvent in events) {
          if (rawEvent is! Map) continue;
          final event = rawEvent.map((key, value) => MapEntry(key.toString(), value));
          final message = event['message'];
          if (event['type'] != 'message_created' || message is! Map) {
            continue;
          }

          final normalized = message.map((key, value) => MapEntry(key.toString(), value));
          await _chatRepository.saveIncomingMessage(normalized);
          final messageId = normalized['_id']?.toString();
          if (messageId != null) deliveredIds.add(messageId);

          if (showNotifications) {
            await _showMissedNotification(event, normalized);
          }

          final eventId = int.tryParse(event['eventId']?.toString() ?? '');
          if (eventId != null && eventId > afterEventId) {
            afterEventId = eventId;
            await _storageService.saveString(_lastEventKey, afterEventId.toString());
          }
        }

        await _receiptService.markDelivered(deliveredIds);
        hasMore = response.data['hasMore'] == true;
      }
    } catch (e) {
      Get.log('Missed message sync failed: $e', isError: true);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _showMissedNotification(
    Map<String, dynamic> event,
    Map<String, dynamic> message,
  ) async {
    if (!Get.isRegistered<ChatNotificationService>()) return;
    final messageId = message['_id']?.toString();
    final senderId = _id(message['sender'] ?? message['senderId']);
    final chatId = _id(message['group'] ?? message['groupId'] ?? message['receiver']) ?? senderId;
    if (messageId == null || chatId == null) return;

    final content = message['content'];
    final preview = content is Map ? content['content']?.toString() ?? '' : '';
    final sender = message['sender'];
    final senderName = sender is Map
        ? (sender['userName'] ?? sender['email'] ?? 'New message').toString()
        : 'New message';

    await Get.find<ChatNotificationService>().showChatMessageNotification(
      chatId: chatId,
      messageId: messageId,
      senderName: senderName,
      preview: preview,
      isGroup: event['chat'] is Map && event['chat']['isGroup'] == true,
      senderId: senderId,
    );
  }

  String? _id(dynamic value) {
    if (value == null) return null;
    if (value is Map) return (value['_id'] ?? value['id'])?.toString();
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
