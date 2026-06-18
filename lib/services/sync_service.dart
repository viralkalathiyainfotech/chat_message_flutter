import 'dart:async';

import 'package:chat_app/features/chats/presentation/controllers/chat_detail_controller.dart';
import 'package:get/get.dart';
import '../core/database/realm_helper.dart';
import '../core/database/realm_models.dart';
import 'connectivity_service.dart';
import 'socket_service.dart';
import 'storage_service.dart';
import '../features/chats/domain/repositories/chat_repository.dart';
import '../features/chats/presentation/controllers/chats_controller.dart';
import '../features/chats/presentation/controllers/groups_controller.dart';
import 'chat_notification_service.dart';
import 'message_sync_service.dart';
import 'receipt_service.dart';

class SyncService extends GetxService {
  final ConnectivityService _connectivityService =
      Get.find<ConnectivityService>();
  final SocketService _socketService = Get.find<SocketService>();
  final StorageService _storageService = Get.find<StorageService>();
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final RealmHelper _realmHelper = RealmHelper();
  ReceiptService? get _receiptService =>
      Get.isRegistered<ReceiptService>() ? Get.find<ReceiptService>() : null;
  MessageSyncService? get _messageSyncService =>
      Get.isRegistered<MessageSyncService>() ? Get.find<MessageSyncService>() : null;
  ChatNotificationService? get _notificationService =>
      Get.isRegistered<ChatNotificationService>()
      ? Get.find<ChatNotificationService>()
      : null;

  final RxnString activeChatUserId = RxnString(null);

  final RxMap<String, bool> typingUsers = <String, bool>{}.obs;
  final RxMap<String, List<String>> typingUserIdsByChat =
      <String, List<String>>{}.obs;
  final Map<String, Timer> _typingClearTimers = {};

  @override
  void onInit() {
    super.onInit();

    // Listen to network changes
    ever(_connectivityService.isOnline, (bool isOnline) {
      if (isOnline && _socketService.isConnected.value) {
        _messageSyncService?.syncMissedMessages();
        _syncOfflineMessages();
      }
    });

    // Listen to socket connection
    ever(_socketService.isConnected, (bool isConnected) {
      if (isConnected && _connectivityService.isOnline.value) {
        _messageSyncService?.syncMissedMessages();
        _syncOfflineMessages();
      }
    });

    // Global listener for incoming messages
    _socketService.onReceiveMessage = (data) async {
      await _chatRepository.saveIncomingMessage(data);
      final chatId = _chatIdFromMessagePayload(data);
      final messageId = (data['_id'] ?? data['messageId'])?.toString();
      if (messageId != null) {
        await _receiptService?.markDelivered([messageId]);
      }

      // If the user is currently on the chat detail screen with this exact user, handle read receipts and reload
      if (activeChatUserId.value != null && chatId == activeChatUserId.value) {
        try {
          final detailController = Get.find<ChatDetailController>(
            tag: activeChatUserId.value,
          );
          detailController.reloadMessagesLocally();
        } catch (_) {}

        if (messageId != null) {
          _socketService.emitMessageRead(messageId);
          await _receiptService?.markRead(chatId: chatId ?? '', messageIds: [messageId]);
          _realmHelper.realm.write(() {
            final msg = _realmHelper.realm.find<MessageRealm>(messageId);
            if (msg != null) msg.status = 'read';
          });
        }
      } else if (chatId != null && messageId != null) {
        await _showForegroundNotificationIfNeeded(data, chatId, messageId);
      }
      _refreshChatsList();
    };

    // Global listener for message sent status
    _socketService.onMessageSentStatus = (data) {
      final messageId = data['messageId'];
      final tempMessageId = data['tempMessageId'];
      final status = data['status'];

      if (messageId != null && status != null) {
        if (tempMessageId != null && tempMessageId != messageId) {
          _chatRepository.replaceTempMessageIdLocally(
            tempMessageId,
            messageId,
            status,
          );
        } else {
          _realmHelper.realm.write(() {
            final msg = _realmHelper.realm.find<MessageRealm>(messageId);
            if (msg != null) msg.status = status;
          });
        }

        if (Get.isRegistered<ChatDetailController>(
          tag: activeChatUserId.value,
        )) {
          try {
            Get.find<ChatDetailController>(
              tag: activeChatUserId.value,
            ).reloadMessagesLocally();
          } catch (_) {}
        }
        _refreshChatsList();
      }
    };

    // Global listener for message read status
    _socketService.onMessageRead = (data) {
      final messageId = data['messageId'] ?? data['_id'];
      final status = data['status'] ?? 'read';

      if (messageId != null) {
        _realmHelper.realm.write(() {
          final msg = _realmHelper.realm.find<MessageRealm>(messageId);
          if (msg != null) msg.status = status;
        });

        if (activeChatUserId.value != null &&
            Get.isRegistered<ChatDetailController>(
              tag: activeChatUserId.value,
            )) {
          try {
            Get.find<ChatDetailController>(
              tag: activeChatUserId.value,
            ).reloadMessagesLocally();
          } catch (_) {}
        }
        _refreshChatsList();
      }
    };

    _socketService.onUserTyping = (data) {
      final userId = _idFromPayload(
        data['userId'] ?? data['senderId'] ?? data['sender'],
      );
      if (userId == null) return;
      final chatId = _chatIdFromTypingPayload(data, userId);
      final isTyping = data['isTyping'] == true;
      if (chatId != null) {
        _setTypingUser(chatId, userId, isTyping);
      }
    };

    _socketService.onMessageDeleted = (data) {
      if (activeChatUserId.value != null &&
          Get.isRegistered<ChatDetailController>(tag: activeChatUserId.value)) {
        try {
          Get.find<ChatDetailController>(
            tag: activeChatUserId.value,
          ).reloadMessagesLocally();
        } catch (_) {}
      }
      _refreshChatsList();
    };

    _socketService.onMessageUpdated = (data) {
      final messageId = data['messageId'];
      final contentData = data['content'];
      if (messageId != null && contentData != null) {
        String content = contentData['content'];
        _chatRepository.updateMessageContentLocally(messageId, content);
        if (activeChatUserId.value != null &&
            Get.isRegistered<ChatDetailController>(
              tag: activeChatUserId.value,
            )) {
          try {
            Get.find<ChatDetailController>(
              tag: activeChatUserId.value,
            ).reloadMessagesLocally();
          } catch (_) {}
        }
        _refreshChatsList();
      }
    };

    _socketService.onMessageReaction = (data) {
      final messageId = data['messageId'];
      final userId = data['userId'];
      final emoji = data['emoji'];
      final action = data['action'];

      if (messageId != null &&
          userId != null &&
          emoji != null &&
          action != null) {
        _chatRepository.handleMessageReactionLocally(
          messageId,
          userId,
          emoji,
          action,
        );
        if (activeChatUserId.value != null &&
            Get.isRegistered<ChatDetailController>(
              tag: activeChatUserId.value,
            )) {
          try {
            Get.find<ChatDetailController>(
              tag: activeChatUserId.value,
            ).reloadMessagesLocally();
          } catch (_) {}
        }
        _refreshChatsList();
      }
    };

    _socketService.onRemoveMessageReaction = (data) {
      final messageId = data['messageId'];
      final userId = data['userId'];
      final emoji = data['emoji'];
      final action = data['action'] ?? 'removed';

      if (messageId != null && userId != null && emoji != null) {
        _chatRepository.handleMessageReactionLocally(
          messageId,
          userId,
          emoji,
          action,
        );
        if (activeChatUserId.value != null &&
            Get.isRegistered<ChatDetailController>(
              tag: activeChatUserId.value,
            )) {
          try {
            Get.find<ChatDetailController>(
              tag: activeChatUserId.value,
            ).reloadMessagesLocally();
          } catch (_) {}
        }
        _refreshChatsList();
      }
    };
  }

  void _refreshChatsList() {
    if (Get.isRegistered<ChatsController>()) {
      try {
        Get.find<ChatsController>().reloadLocalChats();
      } catch (_) {}
    }

    if (Get.isRegistered<GroupsController>()) {
      try {
        Get.find<GroupsController>().reloadLocalGroups();
      } catch (_) {}
    }
  }

  Future<void> _showForegroundNotificationIfNeeded(
    Map<String, dynamic> data,
    String chatId,
    String messageId,
  ) async {
    final notificationService = _notificationService;
    if (notificationService == null || !notificationService.isForeground) {
      return;
    }

    final content = data['content'];
    final preview = content is Map ? content['content']?.toString() ?? '' : '';
    final sender = data['sender'] ?? data['senderId'];
    final senderName = sender is Map
        ? (sender['userName'] ?? sender['email'] ?? 'New message').toString()
        : 'New message';
    await notificationService.showChatMessageNotification(
      chatId: chatId,
      messageId: messageId,
      senderName: senderName,
      preview: preview,
      isGroup: _realmHelper.realm.find<UserRealm>(chatId)?.isGroup == true ||
          data['groupId'] != null ||
          data['group'] != null,
      senderId: _idFromPayload(data['senderId'] ?? data['sender']),
    );
  }

  String? _idFromPayload(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return (value['_id'] ?? value['id'] ?? value['groupId'])?.toString();
    }
    return value.toString();
  }

  String? _chatIdFromMessagePayload(Map<String, dynamic> data) {
    final myId = _storageService.getUserId();
    final senderId = _idFromPayload(data['senderId'] ?? data['sender']);
    final receiverId = _idFromPayload(data['receiverId'] ?? data['receiver']);
    final groupId = _idFromPayload(data['groupId'] ?? data['group']);

    if (groupId != null && groupId.isNotEmpty) return groupId;
    if (receiverId != null && receiverId != myId) return receiverId;
    return senderId;
  }

  String? _chatIdFromTypingPayload(Map<String, dynamic> data, String senderId) {
    final myId = _storageService.getUserId();
    final receiverId = _idFromPayload(
      data['receiverId'] ??
          data['receiver'] ??
          data['groupId'] ??
          data['group'],
    );
    final groupId = _idFromPayload(data['groupId'] ?? data['group']);

    if (groupId != null && groupId.isNotEmpty) return groupId;
    if (receiverId != null && receiverId.isNotEmpty && receiverId != myId) {
      return receiverId;
    }
    return senderId;
  }

  void _setTypingUser(String chatId, String userId, bool isTyping) {
    final myId = _storageService.getUserId();
    if (userId == myId) return;

    typingUsers[userId] = isTyping;

    final timerKey = '$chatId:$userId';
    _typingClearTimers[timerKey]?.cancel();

    final currentIds = List<String>.from(typingUserIdsByChat[chatId] ?? []);
    if (isTyping) {
      if (!currentIds.contains(userId)) currentIds.add(userId);
      typingUserIdsByChat[chatId] = currentIds;
      _typingClearTimers[timerKey] = Timer(const Duration(seconds: 5), () {
        _setTypingUser(chatId, userId, false);
      });
      return;
    }

    currentIds.remove(userId);
    if (currentIds.isEmpty) {
      typingUserIdsByChat.remove(chatId);
    } else {
      typingUserIdsByChat[chatId] = currentIds;
    }
  }

  @override
  void onClose() {
    for (final timer in _typingClearTimers.values) {
      timer.cancel();
    }
    _typingClearTimers.clear();
    super.onClose();
  }

  Future<void> _syncOfflineMessages() async {
    Get.log('Connection restored. Checking pending messages...');

    final pendingMessages = _realmHelper.getPendingMessages();
    final queue = _realmHelper.getQueue();

    if (pendingMessages.isEmpty && queue.isEmpty) {
      Get.log('No pending or queued messages to sync.');
      return;
    }

    final userId = _storageService.getUserId();

    // Sync all pending messages that never got confirmation
    if (pendingMessages.isNotEmpty) {
      Get.log(
        'Syncing ${pendingMessages.length} unconfirmed pending messages...',
      );
      for (var pendingMsg in pendingMessages) {
        if (pendingMsg.senderId == userId &&
            pendingMsg.content != null &&
            pendingMsg.content!.content != null) {
          try {
            await _chatRepository.sendRealtimeMessage(
              pendingMsg.receiverId,
              pendingMsg.content!.content!,
              pendingMsg.content!.type,
              pendingMsg.id,
            );
          } catch (e) {
            Get.log(
              'Failed to resend pending message ${pendingMsg.id}: $e',
              isError: true,
            );
          }
        }
      }
    }

    // Sync traditional queue and clean up
    if (queue.isNotEmpty) {
      Get.log(
        'Clearing ${queue.length} offline queue items as they are handled via pending status...',
      );
      for (var queuedMsg in queue) {
        // We rely on getPendingMessages to handle sending, so just remove from this redundant queue
        _realmHelper.removeFromQueue(queuedMsg.id);
      }
    }
  }
}
