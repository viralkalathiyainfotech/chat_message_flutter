import 'package:chat_app/features/chats/presentation/controllers/chat_detail_controller.dart';
import 'package:get/get.dart';
import '../core/database/realm_helper.dart';
import '../core/database/realm_models.dart';
import 'connectivity_service.dart';
import 'socket_service.dart';
import 'storage_service.dart';
import '../features/chats/domain/repositories/chat_repository.dart';

class SyncService extends GetxService {
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  final SocketService _socketService = Get.find<SocketService>();
  final StorageService _storageService = Get.find<StorageService>();
  final RealmHelper _realmHelper = RealmHelper();
  
  final RxnString activeChatUserId = RxnString(null);

  final RxMap<String, bool> typingUsers = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    
    // Listen to network changes
    ever(_connectivityService.isOnline, (bool isOnline) {
      if (isOnline && _socketService.isConnected.value) {
        _syncOfflineMessages();
      }
    });

    // Listen to socket connection
    ever(_socketService.isConnected, (bool isConnected) {
      if (isConnected && _connectivityService.isOnline.value) {
        _syncOfflineMessages();
      }
    });

    // Global listener for incoming messages
    _socketService.onReceiveMessage = (data) async {
      await Get.find<ChatRepository>().saveIncomingMessage(data);
      
      // If the user is currently on the chat detail screen with this exact user, handle read receipts and reload
      if (activeChatUserId.value != null && 
          (data['sender'] == activeChatUserId.value || data['senderId'] == activeChatUserId.value)) {
         
         try {
           final detailController = Get.find<ChatDetailController>(tag: activeChatUserId.value);
           detailController.reloadMessagesLocally();
         } catch (_) {}
         
         final messageId = data['_id'] ?? data['messageId'];
         if (messageId != null) {
           _socketService.emitMessageRead(messageId);
           _realmHelper.realm.write(() {
              final msg = _realmHelper.realm.find<MessageRealm>(messageId);
              if (msg != null) msg.status = 'read';
           });
         }
      }
    };

    // Global listener for message sent status
    _socketService.onMessageSentStatus = (data) {
      final messageId = data['messageId'];
      final tempMessageId = data['tempMessageId'];
      final status = data['status'];
      
      if (messageId != null && status != null) {
        if (tempMessageId != null && tempMessageId != messageId) {
          Get.find<ChatRepository>().replaceTempMessageIdLocally(tempMessageId, messageId, status);
        } else {
          _realmHelper.realm.write(() {
             final msg = _realmHelper.realm.find<MessageRealm>(messageId);
             if (msg != null) msg.status = status;
          });
        }
        
        if (Get.isRegistered<ChatDetailController>(tag: activeChatUserId.value)) {
          try {
            Get.find<ChatDetailController>(tag: activeChatUserId.value).reloadMessagesLocally();
          } catch (_) {}
        }
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
        
        if (activeChatUserId.value != null && Get.isRegistered<ChatDetailController>(tag: activeChatUserId.value)) {
          try {
            Get.find<ChatDetailController>(tag: activeChatUserId.value).reloadMessagesLocally();
          } catch (_) {}
        }
      }
    };

    _socketService.onUserTyping = (data) {
      final userId = data['userId'] ?? data['senderId'];
      final isTyping = data['isTyping'] == true;
      if (userId != null) {
        typingUsers[userId] = isTyping;
      }
    };

    _socketService.onMessageDeleted = (data) {
      if (activeChatUserId.value != null && Get.isRegistered<ChatDetailController>(tag: activeChatUserId.value)) {
        try {
          Get.find<ChatDetailController>(tag: activeChatUserId.value).reloadMessagesLocally();
        } catch (_) {}
      }
    };

    _socketService.onMessageUpdated = (data) {
      final messageId = data['messageId'];
      final contentData = data['content'];
      if (messageId != null && contentData != null) {
        String content = contentData['content'];
        Get.find<ChatRepository>().updateMessageContentLocally(messageId, content);
        if (activeChatUserId.value != null && Get.isRegistered<ChatDetailController>(tag: activeChatUserId.value)) {
          try {
            Get.find<ChatDetailController>(tag: activeChatUserId.value).reloadMessagesLocally();
          } catch (_) {}
        }
      }
    };

    _socketService.onMessageReaction = (data) {
      final messageId = data['messageId'];
      final userId = data['userId'];
      final emoji = data['emoji'];
      final action = data['action'];
      
      if (messageId != null && userId != null && emoji != null && action != null) {
        Get.find<ChatRepository>().handleMessageReactionLocally(messageId, userId, emoji, action);
        if (activeChatUserId.value != null && Get.isRegistered<ChatDetailController>(tag: activeChatUserId.value)) {
          try {
            Get.find<ChatDetailController>(tag: activeChatUserId.value).reloadMessagesLocally();
          } catch (_) {}
        }
      }
    };

    _socketService.onRemoveMessageReaction = (data) {
      final messageId = data['messageId'];
      final userId = data['userId'];
      final emoji = data['emoji'];
      final action = data['action'] ?? 'removed';
      
      if (messageId != null && userId != null && emoji != null) {
        Get.find<ChatRepository>().handleMessageReactionLocally(messageId, userId, emoji, action);
        if (activeChatUserId.value != null && Get.isRegistered<ChatDetailController>(tag: activeChatUserId.value)) {
          try {
            Get.find<ChatDetailController>(tag: activeChatUserId.value).reloadMessagesLocally();
          } catch (_) {}
        }
      }
    };
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
      Get.log('Syncing ${pendingMessages.length} unconfirmed pending messages...');
      for (var pendingMsg in pendingMessages) {
        if (pendingMsg.senderId == userId && pendingMsg.content != null && pendingMsg.content!.content != null) {
          try {
            await Get.find<ChatRepository>().sendRealtimeMessage(
              pendingMsg.receiverId,
              pendingMsg.content!.content!,
              pendingMsg.content!.type,
              pendingMsg.id,
            );
          } catch (e) {
            Get.log('Failed to resend pending message ${pendingMsg.id}: $e', isError: true);
          }
        }
      }
    }

    // Sync traditional queue and clean up
    if (queue.isNotEmpty) {
      Get.log('Clearing ${queue.length} offline queue items as they are handled via pending status...');
      for (var queuedMsg in queue) {
        // We rely on getPendingMessages to handle sending, so just remove from this redundant queue
        _realmHelper.removeFromQueue(queuedMsg.id);
      }
    }
  }
}
