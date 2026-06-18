import 'dart:async';
import 'dart:io';
import 'package:chat_app/core/database/realm_helper.dart';
import 'package:chat_app/services/sync_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:realm/realm.dart';
import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../services/socket_service.dart';
import '../../../../utils/encryption_util.dart';
import '../../../../services/receipt_service.dart';

class ChatDetailController extends GetxController {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final SocketService _socketService = Get.find<SocketService>();

  final UserRealm remoteUser;

  final RxList<MessageRealm> messages = <MessageRealm>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isTyping = false.obs;
  final RxBool isRemoteTyping = false.obs;
  final RxString remoteTypingText = ''.obs;
  final RxBool isSyncing = false.obs;

  final RxnString editingMessageId = RxnString(null);
  final RxBool hasText = false.obs;
  late RxBool isUserOnline;

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  Timer? _typingTimer;
  Timer? _remoteTypingTimer;
  DateTime? _lastTypingEmit;
  late StreamSubscription<RealmResultsChanges<MessageRealm>>
  _messageSubscription;

  ChatDetailController({required this.remoteUser});

  UserRealm? getUserById(String id) {
    final realmHelper = RealmHelper();
    final users = realmHelper.realm.query<UserRealm>('id == \$0', [id]);
    return users.isNotEmpty ? users.first : null;
  }

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

    _messageSubscription = RealmHelper().realm
        .all<MessageRealm>()
        .changes
        .listen((event) {
          reloadMessagesLocally();
        });

    textController.addListener(_onTextChanged);

    ever(Get.find<SyncService>().typingUsers, (Map<String, bool> typingMap) {
      if (remoteUser.isGroup == true) return;
      if (typingMap[remoteUser.id] == true) {
        isRemoteTyping.value = true;
        remoteTypingText.value = 'typing...';
        _remoteTypingTimer?.cancel();
        _remoteTypingTimer = Timer(const Duration(seconds: 5), () {
          isRemoteTyping.value = false;
          remoteTypingText.value = '';
        });
      } else {
        isRemoteTyping.value = false;
        remoteTypingText.value = '';
        _remoteTypingTimer?.cancel();
      }
    });
    ever(Get.find<SyncService>().typingUserIdsByChat, (
      Map<String, List<String>> typingMap,
    ) {
      if (remoteUser.isGroup != true) return;
      final typingIds = typingMap[remoteUser.id] ?? const <String>[];
      isRemoteTyping.value = typingIds.isNotEmpty;
      remoteTypingText.value = _formatGroupTypingText(typingIds);
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
      if (_lastTypingEmit == null ||
          now.difference(_lastTypingEmit!) > const Duration(seconds: 2)) {
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
    final localMsgs = await _chatRepository.getMessages(
      remoteUser.id,
      fetchFromNetwork: false,
    );
    messages.assignAll(_filterDuplicates(localMsgs.reversed.toList()));
    isLoading.value = false;

    // 2. Sync in background if requested
    if (fetchFromNetwork) {
      isSyncing.value = true;
      final syncedMsgs = await _chatRepository.getMessages(
        remoteUser.id,
        fetchFromNetwork: true,
      );
      messages.assignAll(_filterDuplicates(syncedMsgs.reversed.toList()));
      isSyncing.value = false;
    }

    // Emit read status for any unread messages from the remote user
    final myId = Get.find<StorageService>().getUserId();
    for (var msg in messages) {
      bool isUnread = false;
      if (remoteUser.isGroup == true) {
        if (msg.receiverId == remoteUser.id &&
            msg.senderId != myId &&
            msg.status != 'read') {
          isUnread = true;
        }
      } else {
        if (msg.senderId == remoteUser.id && msg.status != 'read') {
          isUnread = true;
        }
      }

      if (isUnread) {
        _socketService.emitMessageRead(msg.id);
        if (Get.isRegistered<ReceiptService>()) {
          Get.find<ReceiptService>().markRead(
            chatId: remoteUser.id,
            messageIds: [msg.id],
          );
        }
        _chatRepository.updateMessageStatusLocally(msg.id, 'read');
      }
    }
  }

  List<MessageRealm> _filterDuplicates(List<MessageRealm> rawMsgs) {
    final uniqueMsgs = <MessageRealm>[];
    final seen = <String>{};
    for (var msg in rawMsgs) {
      // Use content and second-level timestamp as a unique composite key for the UI
      final timeKey =
          "${msg.createdAt.year}-${msg.createdAt.month}-${msg.createdAt.day}_${msg.createdAt.hour}:${msg.createdAt.minute}:${msg.createdAt.second}";
      final key = "${msg.content?.content}_$timeKey";

      if (!seen.contains(key)) {
        seen.add(key);
        uniqueMsgs.add(msg);
      }
    }
    return uniqueMsgs;
  }

  String _formatGroupTypingText(List<String> typingIds) {
    if (typingIds.isEmpty) return '';
    if (typingIds.length == 1) {
      final user = getUserById(typingIds.first);
      return '${user?.userName ?? 'Someone'} is typing...';
    }
    return '${typingIds.length} are typing...';
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

  Future<void> sendAttachment({
    required String path,
    required String fileName,
    required int sizeBytes,
  }) async {
    if (path.trim().isEmpty || !await File(path).exists()) {
      Get.snackbar('Attachment failed', 'Selected file could not be found.');
      return;
    }

    editingMessageId.value = null;
    isTyping.value = false;
    _socketService.emitTypingStatus(remoteUser.id, false);

    try {
      isSyncing.value = true;
      final uploadedFile = await _chatRepository.uploadAttachment(
        path: path,
        fileName: fileName,
        sizeBytes: sizeBytes,
      );

      await _chatRepository.sendMessage(
        remoteUser.id,
        uploadedFile['content']!,
        'file',
        fileUrl: uploadedFile['fileUrl'],
        fileType: uploadedFile['fileType'],
        size: uploadedFile['size'],
      );

      await _loadMessages(fetchFromNetwork: false);
    } catch (e) {
      Get.log('Attachment send failed: $e', isError: true);
      Get.snackbar('Attachment failed', 'Could not upload or send this file.');
    } finally {
      isSyncing.value = false;
    }
  }

  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    _typingTimer?.cancel();
    _remoteTypingTimer?.cancel();
    _messageSubscription.cancel();

    super.onClose();
  }
}
