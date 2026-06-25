import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:chat_app/core/database/realm_helper.dart';
import 'package:chat_app/services/sync_service.dart';
import 'package:chat_app/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:realm/realm.dart';
import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chats_controller.dart';
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
  final Rxn<MessageRealm> replyingToMessage = Rxn<MessageRealm>();
  final RxSet<String> selectedMessageIds = <String>{}.obs;
  final RxBool hasText = false.obs;
  late RxBool isUserOnline;

  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Audio Recording State
  final RxBool isRecording = false.obs;
  final RxInt recordingDuration = 0.obs;
  Timer? _recordingTimer;

  // Bubble Interaction State
  final RxSet<String> downloadedMessageIds = <String>{}.obs;
  final RxSet<String> activeLiveLocationMessageIds = <String>{}.obs;
  final RxString playingAudioId = ''.obs;
  final RxString audioPlaybackSpeed = 'x1.2'.obs;

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

  bool get isSelectingMessages => selectedMessageIds.isNotEmpty;

  List<MessageRealm> get selectedMessages {
    final ids = selectedMessageIds.toSet();
    return messages.where((message) => ids.contains(message.id)).toList();
  }

  bool isMessageSelected(MessageRealm message) {
    return selectedMessageIds.contains(message.id);
  }

  void toggleMessageSelection(MessageRealm message) {
    if (!selectedMessageIds.add(message.id)) {
      selectedMessageIds.remove(message.id);
    }
    selectedMessageIds.refresh();
  }

  void clearMessageSelection() {
    selectedMessageIds.clear();
  }

  void startReply(MessageRealm message) {
    replyingToMessage.value = message;
    editingMessageId.value = null;
    selectedMessageIds.clear();
  }

  void cancelReply() {
    replyingToMessage.value = null;
  }

  void editMessage(MessageRealm msg) {
    if (msg.content?.type == 'text' && msg.content?.content != null) {
      replyingToMessage.value = null;
      selectedMessageIds.clear();
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
    final replyTo = replyingToMessage.value;
    textController.clear();
    editingMessageId.value = null;
    replyingToMessage.value = null;
    isTyping.value = false;
    _socketService.emitTypingStatus(remoteUser.id, false);

    if (currentEditId != null) {
      await _chatRepository.editMessage(currentEditId, text, 'text');
    } else {
      await _chatRepository.sendMessage(
        remoteUser.id,
        text,
        'text',
        replyTo: replyTo == null ? null : _replyPayload(replyTo),
      );
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
    final replyTo = replyingToMessage.value;
    replyingToMessage.value = null;
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
        replyTo: replyTo == null ? null : _replyPayload(replyTo),
      );

      await _loadMessages(fetchFromNetwork: false);
    } catch (e) {
      Get.log('Attachment send failed: $e', isError: true);
      Get.snackbar('Attachment failed', 'Could not upload or send this file.');
    } finally {
      isSyncing.value = false;
    }
  }

  // Audio Recording Methods
  void startRecording() {
    isRecording.value = true;
    recordingDuration.value = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingDuration.value++;
    });
  }

  void cancelRecording() {
    isRecording.value = false;
    _recordingTimer?.cancel();
    recordingDuration.value = 0;
  }

  Future<void> stopRecording() async {
    if (!isRecording.value) return;
    _recordingTimer?.cancel();
    isRecording.value = false;
    recordingDuration.value = 0;

    final replyTo = replyingToMessage.value;
    replyingToMessage.value = null;

    // Send audio recording message
    await _chatRepository.sendMessage(
      remoteUser.id,
      'Audio Recording',
      'file',
      fileType: 'audio',
      size: '0.10 KB',
      replyTo: replyTo == null ? null : _replyPayload(replyTo),
    );
    await _loadMessages(fetchFromNetwork: false);
  }

  // New Attachment Send Methods
  Future<void> sendContactMessage(String contactName, String phone) async {
    final replyTo = replyingToMessage.value;
    replyingToMessage.value = null;

    await _chatRepository.sendMessage(
      remoteUser.id,
      '$contactName\n$phone',
      'contact',
      replyTo: replyTo == null ? null : _replyPayload(replyTo),
    );
    await _loadMessages(fetchFromNetwork: false);
  }

  Future<void> sendLocationMessage({
    required bool isLive,
    String? duration,
    String? caption,
  }) async {
    final replyTo = replyingToMessage.value;
    replyingToMessage.value = null;

    final content = isLive
        ? 'Live until ${duration ?? '5:18 pm'}'
        : 'Current Location';

    await _chatRepository.sendMessage(
      remoteUser.id,
      caption?.isNotEmpty == true ? '$content\nCaption: $caption' : content,
      'location',
      replyTo: replyTo == null ? null : _replyPayload(replyTo),
    );
    await _loadMessages(fetchFromNetwork: false);
    // Mark as active live location if live
    if (isLive && messages.isNotEmpty) {
      activeLiveLocationMessageIds.add(messages.first.id);
    }
  }

  Future<void> sendAudioAttachment() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.audio);
    if (result != null) {
      final file = result.files.single;
      final path = file.path;
      if (path != null) {
        await sendAttachment(
          path: path,
          fileName: file.name,
          sizeBytes: file.size,
        );
      }
    }
  }

  // Bubble Interaction Methods
  bool isDownloaded(String id) => downloadedMessageIds.contains(id);

  void downloadAttachment(String id) {
    downloadedMessageIds.add(id);
  }

  bool isLiveLocationActive(String id) =>
      activeLiveLocationMessageIds.contains(id);

  void stopLiveLocation(String id) {
    activeLiveLocationMessageIds.remove(id);
  }

  void togglePlayAudio(String id) {
    if (playingAudioId.value == id) {
      playingAudioId.value = '';
    } else {
      playingAudioId.value = id;
    }
  }

  void toggleAudioPlaybackSpeed() {
    if (audioPlaybackSpeed.value == 'x1.0') {
      audioPlaybackSpeed.value = 'x1.2';
    } else if (audioPlaybackSpeed.value == 'x1.2') {
      audioPlaybackSpeed.value = 'x1.5';
    } else if (audioPlaybackSpeed.value == 'x1.5') {
      audioPlaybackSpeed.value = 'x2.0';
    } else {
      audioPlaybackSpeed.value = 'x1.0';
    }
  }

  Future<bool> deleteSelectedMessages() async {
    final ids = selectedMessageIds.toList();
    if (ids.isEmpty) return false;

    try {
      for (final id in ids) {
        await _chatRepository.deleteMessage(id);
      }
      selectedMessageIds.clear();
      await _loadMessages(fetchFromNetwork: false);
      return true;
    } catch (error) {
      Get.log('Delete selected messages failed: $error', isError: true);
      Get.snackbar('Delete messages', error.toString());
      return false;
    }
  }

  Future<bool> forwardMessages({
    required List<MessageRealm> messagesToForward,
    required List<UserRealm> recipients,
  }) async {
    if (messagesToForward.isEmpty || recipients.isEmpty) return false;

    try {
      isSyncing.value = true;
      for (final recipient in recipients) {
        for (final message in messagesToForward) {
          await _chatRepository.forwardMessage(
            message: message,
            recipient: recipient,
          );
        }
      }
      selectedMessageIds.clear();
      await _refreshChatList();
      Get.snackbar('Forward', 'Message forwarded.');
      return true;
    } catch (error) {
      Get.log('Forward messages failed: $error', isError: true);
      Get.snackbar('Forward', error.toString());
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  Map<String, dynamic> _replyPayload(MessageRealm message) {
    final content = message.content;
    return {
      '_id': message.serverId ?? message.id,
      'sender': message.senderId,
      'receiver': message.receiverId,
      'createdAt': message.createdAt.toIso8601String(),
      if (content != null)
        'content': {
          'type': content.type,
          'content': content.content,
          if (content.fileUrl != null) 'fileUrl': content.fileUrl,
          if (content.fileType != null) 'fileType': content.fileType,
          if (content.size != null) 'size': content.size,
        },
    };
  }

  Future<bool> toggleMuteChat() {
    return _runChatAction(
      'Mute chat',
      () => _chatRepository.toggleMuteChat(remoteUser.id),
      successMessage: 'Mute setting updated.',
    );
  }

  Future<bool> togglePinChat() {
    return _runChatAction(
      'Pin chat',
      () => _chatRepository.togglePinChat(remoteUser.id),
      successMessage: 'Pin setting updated.',
    );
  }

  Future<bool> archiveChat() {
    return _runChatAction(
      'Archive chat',
      () => _chatRepository.toggleArchiveChat(remoteUser.id),
      successMessage: 'Archive setting updated.',
    );
  }

  Future<bool> clearChat() {
    return _runChatAction(
      'Clear chat',
      () => _chatRepository.clearChatThread(remoteUser.id),
      successMessage: 'Chat cleared.',
      reloadMessages: true,
    );
  }

  Future<bool> deleteChatThread() {
    return _runChatAction(
      'Delete chat',
      () => _chatRepository.deleteChatThread(remoteUser.id),
      successMessage: 'Chat deleted.',
    );
  }

  Future<bool> blockUser() {
    return _runChatAction(
      'Block user',
      () => _chatRepository.blockUser(remoteUser.id),
      successMessage: 'Block setting updated.',
    );
  }

  Future<bool> blockMember(String memberId) {
    return _runChatAction(
      'Block user',
      () => _chatRepository.blockUser(memberId),
      successMessage: 'Block setting updated.',
    );
  }

  Future<bool> leaveGroup() {
    return _runChatAction(
      'Leave group',
      () => _chatRepository.leaveGroup(remoteUser.id),
      successMessage: 'You left the group.',
    );
  }

  Future<bool> deleteGroup() {
    return _runChatAction(
      'Delete group',
      () => _chatRepository.deleteGroup(remoteUser.id),
      successMessage: 'Group deleted.',
    );
  }

  Future<bool> addParticipants(List<String> memberIds) {
    return _runChatAction(
      'Add members',
      () => _chatRepository.addParticipants(
        groupId: remoteUser.id,
        memberIds: memberIds,
      ),
      successMessage: 'Members added.',
      reloadMessages: true,
    );
  }

  Future<bool> removeGroupMember(String memberId) {
    return _runChatAction(
      'Remove member',
      () => _chatRepository.removeGroupMember(
        groupId: remoteUser.id,
        memberId: memberId,
      ),
      successMessage: 'Member removed.',
      reloadMessages: true,
    );
  }

  Future<bool> updateGroupInfo({
    required String userName,
    String? bio,
    String? photoPath,
  }) {
    return _runChatAction(
      'Group info',
      () => _chatRepository.updateGroupInfo(
        groupId: remoteUser.id,
        userName: userName,
        bio: bio,
        photoPath: photoPath,
      ),
      successMessage: 'Group info updated.',
    );
  }

  Future<bool> _runChatAction(
    String title,
    Future<void> Function() action, {
    required String successMessage,
    bool reloadMessages = false,
  }) async {
    try {
      isSyncing.value = true;
      await action();
      if (reloadMessages) {
        await _loadMessages(fetchFromNetwork: false);
      }
      await _refreshChatList();
      Get.snackbar(title, successMessage);
      return true;
    } catch (error) {
      Get.log('$title failed: $error', isError: true);
      Get.snackbar(title, error.toString());
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _refreshChatList() async {
    if (!Get.isRegistered<ChatsController>()) return;
    await Get.find<ChatsController>().reloadLocalChats();
  }

  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    _typingTimer?.cancel();
    _remoteTypingTimer?.cancel();
    _recordingTimer?.cancel();
    _messageSubscription.cancel();

    super.onClose();
  }
}
