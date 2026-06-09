import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/database/realm_models.dart';
import '../../data/chat_repository.dart';
import '../../../../services/socket_service.dart';

class ChatDetailController extends GetxController {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final SocketService _socketService = Get.find<SocketService>();
  
  final UserRealm remoteUser;
  
  final RxList<MessageRealm> messages = <MessageRealm>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isTyping = false.obs;
  final RxBool isRemoteTyping = false.obs;

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  
  Timer? _typingTimer;

  ChatDetailController({required this.remoteUser});

  @override
  void onInit() {
    super.onInit();
    _loadMessages();
    
    textController.addListener(_onTextChanged);
    
    // Listen to socket events
    _socketService.onReceiveMessage = (data) {
      if (data['sender'] == remoteUser.id || data['receiver'] == remoteUser.id) {
        _loadMessages(); // Reload from Realm when a new message is saved
      }
    };

    _socketService.onUserTyping = (data) {
      if (data['userId'] == remoteUser.id) {
        isRemoteTyping.value = data['isTyping'] ?? false;
      }
    };
    
    _socketService.onMessageSentStatus = (data) {
      // Refresh messages to update "pending" / "sent" / "delivered" status
      _loadMessages();
    };
  }

  void _onTextChanged() {
    if (textController.text.isNotEmpty && !isTyping.value) {
      isTyping.value = true;
      _socketService.emitTypingStatus(remoteUser.id, true);
    } else if (textController.text.isEmpty && isTyping.value) {
      isTyping.value = false;
      _socketService.emitTypingStatus(remoteUser.id, false);
      _typingTimer?.cancel();
    }

    if (textController.text.isNotEmpty) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        isTyping.value = false;
        _socketService.emitTypingStatus(remoteUser.id, false);
      });
    }
  }

  Future<void> _loadMessages() async {
    final msgs = await _chatRepository.getMessages(remoteUser.id);
    messages.value = msgs.reversed.toList(); // Assuming we want newest at the bottom and we use a reversed ListView
    isLoading.value = false;
  }

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    
    textController.clear();
    isTyping.value = false;
    _socketService.emitTypingStatus(remoteUser.id, false);

    // Optimistically add to UI, but actually _chatRepository does this by saving to Realm first.
    await _chatRepository.sendMessage(remoteUser.id, text, 'text');
    await _loadMessages(); // Reload from local db
  }

  Future<void> sendAttachment(String fileUrl, String fileType, String size) async {
    // This will handle the actual attachment sending once uploaded
  }

  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    _typingTimer?.cancel();
    _socketService.onReceiveMessage = null;
    _socketService.onUserTyping = null;
    _socketService.onMessageSentStatus = null;
    super.onClose();
  }
}
