import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../services/socket_service.dart';
import '../../../../utils/encryption_util.dart';

class ChatDetailController extends GetxController {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final SocketService _socketService = Get.find<SocketService>();
  
  final UserRealm remoteUser;
  
  final RxList<MessageRealm> messages = <MessageRealm>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isTyping = false.obs;
  final RxBool isRemoteTyping = false.obs;
  final RxBool isSyncing = false.obs;
  
  final RxnString editingMessageId = RxnString(null);
  final RxBool hasText = false.obs;
  late RxBool isUserOnline;

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  
  Timer? _typingTimer;
  Timer? _remoteTypingTimer;
  DateTime? _lastTypingEmit;

  ChatDetailController({required this.remoteUser});

  @override
  void onInit() {
    super.onInit();
    
    isUserOnline = (remoteUser.isOnline ?? false).obs;
    
    // Force socket connection if it hasn't connected
    _socketService.connect();
    
    // Fetch initial online status
    Future.delayed(const Duration(milliseconds: 500), () {
      _socketService.getOnlineUsers();
    });
    
    _loadMessages();
    
    textController.addListener(_onTextChanged);
    
    _socketService.onUserTyping = (data) {
      print('==== ON USER TYPING RECEIVED: $data ====');
      print('==== COMPARING WITH REMOTE USER ID: ${remoteUser.id} ====');
      
      if (data['userId'] == remoteUser.id || data['senderId'] == remoteUser.id) {
        if (data['isTyping'] == true) {
          isRemoteTyping.value = true;
          _remoteTypingTimer?.cancel();
          _remoteTypingTimer = Timer(const Duration(seconds: 5), () {
            isRemoteTyping.value = false;
          });
        } else {
          isRemoteTyping.value = false;
          _remoteTypingTimer?.cancel();
        }
      }
    };
    _socketService.onUserStatusChanged = (onlineUsersList) {
      print('==== ON USER STATUS CHANGED: $onlineUsersList ====');
      print('==== COMPARING WITH REMOTE USER ID: ${remoteUser.id} ====');
      if (onlineUsersList.contains(remoteUser.id)) {
        isUserOnline.value = true;
      } else {
        isUserOnline.value = false;
      }
    };

    _socketService.onMessageRead = (data) {
      final messageId = data['messageId'];
      if (messageId != null) {
        _updateLocalMessageStatus(messageId, 'read');
      }
    };

    _socketService.onMessageDeleted = (data) {
      _loadMessages();
    };

    _socketService.onMessageUpdated = (data) {
      final messageId = data['messageId'];
      final contentData = data['content'];
      if (messageId != null && contentData != null) {
        String content = contentData['content'];
        _chatRepository.updateMessageContentLocally(messageId, content);
      }
      _loadMessages(fetchFromNetwork: false);
    };

    _socketService.onMessageReaction = (data) {
      final messageId = data['messageId'];
      final userId = data['userId'];
      final emoji = data['emoji'];
      final action = data['action'];
      
      if (messageId != null && userId != null && emoji != null && action != null) {
        _chatRepository.handleMessageReactionLocally(messageId, userId, emoji, action);
      }
      _loadMessages(fetchFromNetwork: false);
    };

    _socketService.onRemoveMessageReaction = (data) {
      final messageId = data['messageId'];
      final userId = data['userId'];
      final emoji = data['emoji'];
      final action = data['action'] ?? 'removed'; // Backend doesn't explicitly send action for remove? Wait, backend handles it all in handleMessageReaction.
      
      if (messageId != null && userId != null && emoji != null) {
        _chatRepository.handleMessageReactionLocally(messageId, userId, emoji, action);
      }
      _loadMessages(fetchFromNetwork: false);
    };
  }

  void reloadMessagesLocally() {
    _loadMessages(fetchFromNetwork: false);
  }

  void _updateLocalMessageStatus(String messageId, String status) {
    // Update local database. Realm objects are live, so this updates the references in memory.
    _chatRepository.updateMessageStatusLocally(messageId, status);
    
    // Update RxList to trigger UI refresh instantly
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages.refresh();
    }
  }

  void _onTextChanged() {
    hasText.value = textController.text.trim().isNotEmpty;
    if (textController.text.isNotEmpty) {
      final now = DateTime.now();
      // Throttle emitting typing status to once every 2 seconds
      if (_lastTypingEmit == null || now.difference(_lastTypingEmit!) > const Duration(seconds: 2)) {
        isTyping.value = true;
        _socketService.emitTypingStatus(remoteUser.id, true);
        _lastTypingEmit = now;
      }

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        isTyping.value = false;
        // Emit false when typing stops, even though the React frontend relies on a 5s timeout
        _socketService.emitTypingStatus(remoteUser.id, false);
      });
    } else {
      isTyping.value = false;
      _socketService.emitTypingStatus(remoteUser.id, false);
      _typingTimer?.cancel();
    }
  }

  Future<void> _loadMessages({bool fetchFromNetwork = true}) async {
    // 1. Load instantly from local database
    isLoading.value = true;
    final localMsgs = await _chatRepository.getMessages(remoteUser.id, fetchFromNetwork: false);
    messages.assignAll(_filterDuplicates(localMsgs.reversed.toList()));
    isLoading.value = false;
    
    // 2. Sync in background if requested
    if (fetchFromNetwork) {
      isSyncing.value = true;
      final syncedMsgs = await _chatRepository.getMessages(remoteUser.id, fetchFromNetwork: true);
      messages.assignAll(_filterDuplicates(syncedMsgs.reversed.toList()));
      isSyncing.value = false;
    }
    
    // Emit read status for any unread messages from the remote user
    for (var msg in messages) {
      if (msg.senderId == remoteUser.id && msg.status != 'read') {
        _socketService.emitMessageRead(msg.id);
        _chatRepository.updateMessageStatusLocally(msg.id, 'read');
      }
    }
  }

  List<MessageRealm> _filterDuplicates(List<MessageRealm> rawMsgs) {
    final uniqueMsgs = <MessageRealm>[];
    final seen = <String>{};
    for (var msg in rawMsgs) {
      // Use content and second-level timestamp as a unique composite key for the UI
      // final timeKey = "\${msg.createdAt.year}-\${msg.createdAt.month}-\${msg.createdAt.day}_\${msg.createdAt.hour}:\${msg.createdAt.minute}:\${msg.createdAt.second}";
      final key = "\${msg.content?.content}_\${timeKey}";
      
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueMsgs.add(msg);
      }
    }
    return uniqueMsgs;
  }

  void editMessage(MessageRealm msg) {
    if (msg.content?.type == 'text' && msg.content?.content != null) {
      editingMessageId.value = msg.id;
      textController.text = EncryptionUtil.decrypt(msg.content!.content!);
    }
  }

  void cancelEdit() {
    editingMessageId.value = null;
    textController.clear();
  }

  Future<void> deleteMessage(String messageId) async {
    await _chatRepository.deleteMessage(messageId);
    await _loadMessages();
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    await _chatRepository.reactToMessage(messageId, emoji);
    // Optimistic UI update or wait for reload, _loadMessages will be triggered by socket anyway
  }

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    
    final currentEditId = editingMessageId.value;
    textController.clear();
    editingMessageId.value = null;
    isTyping.value = false;
    _socketService.emitTypingStatus(remoteUser.id, false);

    if (currentEditId != null) {
      await _chatRepository.editMessage(currentEditId, text, 'text');
    } else {
      await _chatRepository.sendMessage(remoteUser.id, text, 'text');
    }
    
    await _loadMessages(fetchFromNetwork: false); // Reload from local db only
  }

  Future<void> sendAttachment(String fileUrl, String fileType, String size) async {
    // This will handle the actual attachment sending once uploaded
  }

  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    _typingTimer?.cancel();
    _remoteTypingTimer?.cancel();
    _socketService.onReceiveMessage = null;
    _socketService.onUserTyping = null;
    _socketService.onMessageSentStatus = null;
    _socketService.onMessageRead = null;
    _socketService.onMessageDeleted = null;
    _socketService.onMessageUpdated = null;
    _socketService.onMessageReaction = null;
    _socketService.onRemoveMessageReaction = null;
    super.onClose();
  }
}
