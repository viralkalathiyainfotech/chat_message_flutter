import 'dart:async';
import 'package:chat_app/services/sync_service.dart';
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
    
    ever(Get.find<SyncService>().typingUsers, (Map<String, bool> typingMap) {
      if (typingMap[remoteUser.id] == true) {
        isRemoteTyping.value = true;
        _remoteTypingTimer?.cancel();
        _remoteTypingTimer = Timer(const Duration(seconds: 5), () {
          isRemoteTyping.value = false;
        });
      } else {
        isRemoteTyping.value = false;
        _remoteTypingTimer?.cancel();
      }
    });
    _socketService.onUserStatusChanged = (onlineUsersList) {
      Get.log('==== ON USER STATUS CHANGED: $onlineUsersList ====');
      Get.log('==== COMPARING WITH REMOTE USER ID: ${remoteUser.id} ====');
      if (onlineUsersList.contains(remoteUser.id)) {
        isUserOnline.value = true;
      } else {
        isUserOnline.value = false;
      }
    };


  }

  void reloadMessagesLocally() {
    _loadMessages(fetchFromNetwork: false);
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
    if (messages.isEmpty) {
      isLoading.value = true;
    }
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
      final timeKey = "${msg.createdAt.year}-${msg.createdAt.month}-${msg.createdAt.day}_${msg.createdAt.hour}:${msg.createdAt.minute}:${msg.createdAt.second}";
      final key = "${msg.content?.content}_$timeKey";
      
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

    super.onClose();
  }
}
