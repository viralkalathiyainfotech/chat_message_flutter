import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';

import '../../../../constants/color_constants.dart';
import '../../../../constants/asset_constants.dart';
import '../../../calls/presentation/controllers/call_controller.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../utils/encryption_util.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/widgets/animations/animated_chat_bubble.dart';
import '../../../../services/sync_service.dart';
import '../controllers/chat_detail_controller.dart';
import 'add_existing_group_members_screen.dart';
import 'forward_messages_screen.dart';
import 'chat_info_screens.dart';
import 'send_contact_screen.dart';
import 'send_location_screen.dart';
import 'gallery_selection_preview_screen.dart';
import 'camera_capture_screen.dart';
import 'media_viewer_screen.dart';
import '../widgets/attachment_bottom_sheet.dart';

enum _ChatDetailMenuAction {
  viewContact,
  search,
  mute,
  pin,
  screenShare,
  archive,
  clear,
  delete,
  block,
  addMembers,
  leave,
}

class ChatDetailScreen extends StatefulWidget {
  final UserRealm user;

  const ChatDetailScreen({super.key, required this.user});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late ChatDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      ChatDetailController(remoteUser: widget.user),
      tag: widget.user.id,
    );
    // Mark as active chat
    if (Get.isRegistered<SyncService>()) {
      Get.find<SyncService>().activeChatUserId.value = widget.user.id;
    }
  }

  @override
  void dispose() {
    // Clear active chat
    if (Get.isRegistered<SyncService>()) {
      Get.find<SyncService>().activeChatUserId.value = null;
    }
    Get.delete<ChatDetailController>(tag: widget.user.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, controller),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(controller)),
          _buildInputBar(context, controller),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ChatDetailController controller,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Obx(
        () => controller.isSelectingMessages
            ? _buildMessageSelectionAppBar(context, controller)
            : _buildNormalAppBar(context, controller),
      ),
    );
  }

  AppBar _buildNormalAppBar(
    BuildContext context,
    ChatDetailController controller,
  ) {
    final user = widget.user;
    final isGroupChat = _isGroupChat(user);
    return AppBar(
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leadingWidth: 50,
      title: GestureDetector(
        onTap: () {
          if (isGroupChat) {
            Get.to(
              () => GroupProfileScreen(group: user, controller: controller),
            );
          } else {
            Get.to(() => UserProfileScreen(user: user, controller: controller));
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: user.photo != null
                  ? CachedNetworkImageProvider(user.photo!)
                  : null,
              child: user.photo == null
                  ? Icon(isGroupChat ? Icons.group : Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.userName ?? 'User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(() {
                    if (controller.isRemoteTyping.value) {
                      return Text(
                        controller.remoteTypingText.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorConstants.primaryBlue,
                        ),
                      );
                    }

                    if (isGroupChat) {
                      final count = _groupMemberIds(user)?.length ?? 0;
                      return Text(
                        '$count members',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    }

                    return Text(
                      controller.isUserOnline.value ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: controller.isUserOnline.value
                            ? Colors.green
                            : Colors.grey,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () {
            Get.find<CallController>().startCall(
              controller.remoteUser.id,
              video: true,
              isGroup: isGroupChat,
              participants: _groupMemberIds(user),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () {
            Get.find<CallController>().startCall(
              controller.remoteUser.id,
              video: false,
              isGroup: isGroupChat,
              participants: _groupMemberIds(user),
            );
          },
        ),
        PopupMenuButton<_ChatDetailMenuAction>(
          icon: const Icon(Icons.more_vert),
          color: const Color(0xFF2F2F2F),
          elevation: 8,
          offset: const Offset(0, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          onSelected: (action) =>
              _handleMenuAction(context, controller, action, isGroupChat),
          itemBuilder: (context) =>
              isGroupChat ? _groupMenuItems() : _privateMenuItems(),
        ),
      ],
    );
  }

  AppBar _buildMessageSelectionAppBar(
    BuildContext context,
    ChatDetailController controller,
  ) {
    final selectedMessages = controller.selectedMessages;
    final selectedCount = selectedMessages.length;
    final currentUserId = Get.find<StorageService>().getUserId();
    final canEdit =
        selectedCount == 1 &&
        selectedMessages.first.senderId == currentUserId &&
        selectedMessages.first.content?.type == 'text';

    return AppBar(
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leadingWidth: 76,
      leading: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: controller.clearMessageSelection,
          ),
          Text(
            selectedCount.toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Reply',
          icon: const Icon(Icons.reply, size: 20),
          onPressed: selectedCount == 1
              ? () => controller.startReply(selectedMessages.first)
              : null,
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy_outlined, size: 19),
          onPressed: selectedMessages.isEmpty
              ? null
              : () => _copySelectedMessages(controller),
        ),
        IconButton(
          tooltip: 'Forward',
          icon: const Icon(Icons.forward, size: 20),
          onPressed: selectedMessages.isEmpty
              ? null
              : () => Get.to(
                  () => ForwardMessagesScreen(
                    messages: List<MessageRealm>.from(selectedMessages),
                    controller: controller,
                  ),
                ),
        ),
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined, size: 19),
          onPressed: canEdit
              ? () => controller.editMessage(selectedMessages.first)
              : null,
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: selectedMessages.isEmpty
              ? null
              : () => _showDeleteMessagesSheet(context, controller),
        ),
      ],
    );
  }

  List<PopupMenuEntry<_ChatDetailMenuAction>> _privateMenuItems() {
    return [
      _menuItem(
        _ChatDetailMenuAction.viewContact,
        Icons.person_outline,
        'View Contact',
      ),
      _menuItem(_ChatDetailMenuAction.search, Icons.search, 'Search'),
      _menuItem(
        _ChatDetailMenuAction.mute,
        Icons.notifications_off_outlined,
        'Mute',
      ),
      _menuItem(_ChatDetailMenuAction.pin, Icons.push_pin_outlined, 'Pin Chat'),
      _menuItem(
        _ChatDetailMenuAction.screenShare,
        Icons.screen_share_outlined,
        'Screen Share',
      ),
      _menuItem(
        _ChatDetailMenuAction.archive,
        Icons.archive_outlined,
        'Archive Chat',
      ),
      _menuItem(
        _ChatDetailMenuAction.clear,
        Icons.cancel_outlined,
        'Clear Chat',
      ),
      _menuItem(
        _ChatDetailMenuAction.delete,
        Icons.delete_outline,
        'Delete Chat',
      ),
      _menuItem(
        _ChatDetailMenuAction.block,
        Icons.block,
        'Block',
        danger: true,
      ),
    ];
  }

  List<PopupMenuEntry<_ChatDetailMenuAction>> _groupMenuItems() {
    return [
      _menuItem(
        _ChatDetailMenuAction.mute,
        Icons.notifications_off_outlined,
        'Mute',
      ),
      _menuItem(_ChatDetailMenuAction.pin, Icons.push_pin_outlined, 'Pin Chat'),
      _menuItem(
        _ChatDetailMenuAction.addMembers,
        Icons.person_add_alt_1_outlined,
        'Add Members',
      ),
      _menuItem(
        _ChatDetailMenuAction.archive,
        Icons.archive_outlined,
        'Archive Chat',
      ),
      _menuItem(
        _ChatDetailMenuAction.clear,
        Icons.cancel_outlined,
        'Clear Chat',
      ),
      _menuItem(
        _ChatDetailMenuAction.delete,
        Icons.delete_outline,
        'Delete Chat',
      ),
      _menuItem(
        _ChatDetailMenuAction.leave,
        Icons.logout,
        'Leave Chat',
        danger: true,
      ),
    ];
  }

  PopupMenuItem<_ChatDetailMenuAction> _menuItem(
    _ChatDetailMenuAction action,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    return PopupMenuItem<_ChatDetailMenuAction>(
      value: action,
      height: 46,
      child: _ChatDetailMenuItem(icon: icon, label: label, danger: danger),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    ChatDetailController controller,
    _ChatDetailMenuAction action,
    bool isGroupChat,
  ) async {
    switch (action) {
      case _ChatDetailMenuAction.viewContact:
        _showContactInfo(context);
        return;
      case _ChatDetailMenuAction.search:
        Get.snackbar('Search', 'Chat search is not available yet.');
        return;
      case _ChatDetailMenuAction.mute:
        await controller.toggleMuteChat();
        return;
      case _ChatDetailMenuAction.pin:
        await controller.togglePinChat();
        return;
      case _ChatDetailMenuAction.screenShare:
        await _startScreenShareFromMenu();
        return;
      case _ChatDetailMenuAction.addMembers:
        await Get.to(
          () => AddExistingGroupMembersScreen(
            group: widget.user,
            controller: controller,
            existingMemberIds: _groupMemberIds(widget.user) ?? const <String>[],
          ),
        );
        return;
      case _ChatDetailMenuAction.archive:
        if (await controller.archiveChat() && mounted) {
          Get.back();
        }
        return;
      case _ChatDetailMenuAction.clear:
        final confirmed = await _confirmMenuAction(
          context,
          title: 'Clear chat?',
          message: 'This will clear the messages from this chat.',
          actionLabel: 'Clear',
          danger: true,
        );
        if (confirmed) {
          await controller.clearChat();
        }
        return;
      case _ChatDetailMenuAction.delete:
        final confirmed = await _confirmMenuAction(
          context,
          title: isGroupChat ? 'Delete group chat?' : 'Delete chat?',
          message: 'This will remove this chat from your chat list.',
          actionLabel: 'Delete',
          danger: true,
        );
        if (confirmed && await controller.deleteChatThread() && mounted) {
          Get.back();
        }
        return;
      case _ChatDetailMenuAction.block:
        final confirmed = await _confirmMenuAction(
          context,
          title: 'Block contact?',
          message: 'You will no longer receive messages from this contact.',
          actionLabel: 'Block',
          danger: true,
        );
        if (confirmed) {
          await controller.blockUser();
        }
        return;
      case _ChatDetailMenuAction.leave:
        final confirmed = await _confirmMenuAction(
          context,
          title: 'Leave group?',
          message: 'You will stop receiving messages from this group.',
          actionLabel: 'Leave',
          danger: true,
        );
        if (confirmed && await controller.leaveGroup() && mounted) {
          Get.back();
        }
        return;
    }
  }

  Future<void> _startScreenShareFromMenu() async {
    if (!Get.isRegistered<CallController>()) {
      Get.snackbar('Screen share', 'Call controls are not ready yet.');
      return;
    }

    final callService = Get.find<CallController>().callService;
    if (!callService.isInCall.value || !callService.isVideoCall) {
      Get.snackbar(
        'Screen share',
        'Start a video call before sharing your screen.',
      );
      return;
    }

    await callService.toggleScreenShare();
  }

  Future<bool> _confirmMenuAction(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              actionLabel,
              style: TextStyle(color: danger ? Colors.red : null),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showContactInfo(BuildContext context) {
    final user = widget.user;
    final hasPhoto = user.photo != null && user.photo!.startsWith('http');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundImage: hasPhoto
                    ? CachedNetworkImageProvider(user.photo!)
                    : null,
                child: hasPhoto
                    ? null
                    : Icon(user.isGroup == true ? Icons.group : Icons.person),
              ),
              const SizedBox(height: 12),
              Text(
                user.userName ?? 'User',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (user.mobileNumber?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  user.mobileNumber!,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              if (user.email?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  user.email!,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              if (user.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  user.bio!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isGroupChat(UserRealm user) {
    final members = _groupMemberIds(user);
    return user.isGroup == true && members != null && members.isNotEmpty;
  }

  List<String>? _groupMemberIds(UserRealm user) {
    if (user.isGroup != true || user.membersListJson == null) return null;
    try {
      final decoded = jsonDecode(user.membersListJson!);
      if (decoded is! List) return null;
      return decoded
          .map((member) {
            if (member is Map) {
              return (member['_id'] ?? member['id'])?.toString();
            }
            return member?.toString();
          })
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      Get.log('Error decoding group members: $e', isError: true);
      return null;
    }
  }

  Widget _buildMessageList(ChatDetailController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.messages.isEmpty) {
        return const Center(
          child: Text('No messages yet', style: TextStyle(color: Colors.grey)),
        );
      }
      return ListView.builder(
        reverse: true, // start from bottom
        controller: controller.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          final currentUserId = Get.find<StorageService>().getUserId();
          final isMe = message.senderId == currentUserId;
          final isSelected = controller.isMessageSelected(message);

          bool needsExtraTopPadding = false;
          if (index < controller.messages.length - 1) {
            final aboveMessage = controller.messages[index + 1];
            final currentMessage = controller.messages[index];
            if ((aboveMessage.senderId == currentMessage.senderId) &&
                aboveMessage.reactions.isNotEmpty) {
              needsExtraTopPadding = true;
            }
          }

          return _buildChatBubble(
            message,
            isMe,
            isSelected,
            needsExtraTopPadding,
            context,
            controller,
          );
        },
      );
    });
  }

  Widget _formatSystemMessage(String text) {
    if (text.contains('**')) {
      final parts = text.split('**');
      final spans = <TextSpan>[];
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        if (i % 2 == 1) {
          spans.add(
            TextSpan(
              text: parts[i],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: parts[i],
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          );
        }
      }
      return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
    }

    if (text.contains(' removed ')) {
      final parts = text.split(' removed ');
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: parts[0],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: ' removed ${parts[1]}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    );
  }

  Widget _buildChatBubble(
    MessageRealm message,
    bool isMe,
    bool isSelected,
    bool needsExtraTopPadding,
    BuildContext context,
    ChatDetailController controller,
  ) {
    if (message.content?.type == 'system') {
      final text = message.content?.content ?? 'System message';
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _formatSystemMessage(text),
        ),
      );
    }

    return AnimatedChatBubble(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () {
          if (controller.isSelectingMessages) {
            controller.toggleMessageSelection(message);
          }
        },
        onLongPress: () => controller.toggleMessageSelection(message),
        child: Container(
          width: double.infinity,
          color: isSelected
              ? ColorConstants.primaryBlue.withValues(alpha: 0.13)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              if (isSelected)
                _SelectedReactionBar(
                  onReact: (emoji) {
                    controller.reactToMessage(message.id, emoji);
                    controller.clearMessageSelection();
                  },
                ),
              Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Sender name for group chats
                        if (!isMe && controller.remoteUser.isGroup == true) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2, left: 4),
                            child: Builder(
                              builder: (context) {
                                final sender = controller.getUserById(
                                  message.senderId,
                                );
                                return Text(
                                  sender?.userName ?? 'Unknown User',
                                  style: TextStyle(
                                    color: ColorConstants.primaryBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        // Time above the bubble
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 4,
                            left: 4,
                            right: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe) ...[
                                const Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  message.isPending
                                      ? Icons.access_time
                                      : (message.status == 'sent'
                                            ? Icons.done
                                            : Icons.done_all),
                                  size: 14,
                                  color: message.status == 'read'
                                      ? Colors.lightBlueAccent
                                      : Colors.grey,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(
                            bottom: message.reactions.isNotEmpty ? 16 : 8,
                            top: needsExtraTopPadding ? 16 : 4,
                          ),
                          padding:
                              (message.content?.type == 'image' ||
                                  message.content?.type == 'location')
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: (message.content?.type == 'call')
                                ? Theme.of(context).cardColor
                                : (isMe
                                      ? ColorConstants.primaryBlue
                                      : Theme.of(context).cardColor),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: isMe
                                  ? Radius.zero
                                  : const Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (message.content?.type == 'text')
                                Text(
                                  EncryptionUtil.decrypt(
                                    message.content?.content ?? '',
                                  ),
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                    fontSize: 15,
                                  ),
                                )
                              else if (message.content?.type == 'image' ||
                                  (message.content?.type == 'file' &&
                                      (message.content?.fileType?.contains(
                                            'image',
                                          ) ??
                                          false)))
                                _buildImageBubble(
                                  message,
                                  isMe,
                                  context,
                                  controller,
                                )
                              else if (message.content?.type == 'call')
                                _buildCallBubble(message, isMe, context)
                              else if (message.content?.type == 'location')
                                _buildLocationBubble(
                                  message,
                                  isMe,
                                  context,
                                  controller,
                                )
                              else if (message.content?.type == 'contact')
                                _buildContactBubble(message, isMe, context)
                              else if (message.content?.type == 'file' &&
                                  (message.content?.fileType?.contains(
                                        'audio',
                                      ) ??
                                      false))
                                _buildAudioBubble(
                                  message,
                                  isMe,
                                  context,
                                  controller,
                                )
                              else if (message.content?.type == 'file')
                                _buildDocumentBubble(
                                  message,
                                  isMe,
                                  context,
                                  controller,
                                )
                              else if (message.content?.type == 'system')
                                Text(
                                  message.content?.content?.replaceAll(
                                        '**',
                                        '',
                                      ) ??
                                      'System message',
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                )
                              else
                                Text(
                                  'Attachment: ${message.content?.type}',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),

                              if (message.edited) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Floating Reactions
                    if (message.reactions.isNotEmpty)
                      Positioned(
                        bottom: -8,
                        right: isMe ? 12 : null,
                        left: isMe ? null : 12,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.reactions
                                    .map((r) => r.emoji)
                                    .toSet()
                                    .join(' '),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.1,
                                ),
                              ),
                              if (message.reactions.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    '${message.reactions.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatDetailController controller) {
    if (widget.user.isGroup == true) {
      final currentUserId = Get.find<StorageService>().getUserId();
      final memberIds = _groupMemberIds(widget.user) ?? [];
      if (!memberIds.contains(currentUserId)) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: Theme.of(context).cardColor,
          alignment: Alignment.center,
          child: const Text(
            'User is unable to send messages in this group chat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(() {
          final replyMessage = controller.replyingToMessage.value;
          if (replyMessage == null) return const SizedBox.shrink();

          return _ReplyPreviewBar(
            message: replyMessage,
            senderName: _messageSenderLabel(replyMessage),
            previewText: _messagePreviewText(replyMessage),
            onClose: controller.cancelReply,
          );
        }),
        Obx(() {
          if (controller.editingMessageId.value != null) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Editing message',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                  InkWell(
                    onTap: controller.cancelEdit,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        Obx(() {
          if (controller.isRecording.value) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => controller.cancelRecording(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ColorConstants.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          18,
                          (index) => Container(
                            width: 3,
                            height: (index % 3 == 0)
                                ? 24
                                : ((index % 2 == 0) ? 14 : 32),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '00:${controller.recordingDuration.value.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => controller.stopRecording(),
                      child: Icon(
                        Icons.send,
                        color: ColorConstants.primaryBlue,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.emoji_emotions_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: TextField(
                              controller: controller.textController,
                              maxLines: 4,
                              minLines: 1,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: SvgPicture.asset(
                              AssetConstants.attachmentsIcon,
                              colorFilter: const ColorFilter.mode(
                                Colors.grey,
                                BlendMode.srcIn,
                              ),
                            ),
                            onPressed: () =>
                                _showAttachmentMenu(context, controller),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Obx(() {
                    final hasText = controller.hasText.value;
                    return GestureDetector(
                      onTap: () {
                        if (hasText) {
                          controller.sendMessage();
                        } else {
                          controller.startRecording();
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ColorConstants.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: hasText
                            ? const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              )
                            : SvgPicture.asset(
                                AssetConstants.micIcon,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                                fit: BoxFit.scaleDown,
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _copySelectedMessages(ChatDetailController controller) async {
    final copiedText = controller.selectedMessages
        .map(_messagePreviewText)
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
    if (copiedText.isEmpty) {
      Get.snackbar('Copy', 'This message cannot be copied.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: copiedText));
    controller.clearMessageSelection();
    Get.snackbar('Copy', 'Message copied.');
  }

  Future<void> _showDeleteMessagesSheet(
    BuildContext context,
    ChatDetailController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Delete Messages',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: Get.back,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Deleting your chats erases all\ndata. Confirm Deletion?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: Get.back,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final deleted = await controller
                              .deleteSelectedMessages();
                          if (deleted) {
                            Get.back();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorConstants.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Delete for everyone'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _messageSenderLabel(MessageRealm message) {
    final currentUserId = Get.find<StorageService>().getUserId();
    if (message.senderId == currentUserId) return 'You';
    return controller.getUserById(message.senderId)?.userName ??
        widget.user.userName ??
        'User';
  }

  String _messagePreviewText(MessageRealm message) {
    final content = message.content;
    if (content == null) return '';
    if (content.type == 'text') {
      return EncryptionUtil.decrypt(content.content ?? '');
    }
    if (content.type == 'file' && content.fileType?.contains('image') == true) {
      return content.content ?? 'Photo';
    }
    if (content.type == 'file') {
      return content.content ?? 'Document';
    }
    if (content.type == 'system') {
      return content.content?.replaceAll('**', '') ?? 'System message';
    }
    return content.content ?? content.type;
  }

  void _showAttachmentMenu(
    BuildContext context,
    ChatDetailController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentBottomSheet(
        onDocumentTap: () async {
          FilePickerResult? result = await FilePicker.pickFiles();
          if (result != null) {
            final file = result.files.single;
            final path = file.path;
            if (path == null) {
              Get.snackbar(
                'Attachment failed',
                'Selected file is not available on this device.',
              );
              return;
            }

            await controller.sendAttachment(
              path: path,
              fileName: file.name,
              sizeBytes: file.size,
            );
          }
        },
        onCameraTap: () {
          Get.back();
          Get.to(() => CameraCaptureScreen(chatController: controller));
        },
        onGalleryTap: () async {
          final ImagePicker picker = ImagePicker();
          final List<XFile> images = await picker.pickMultiImage();
          if (images.isNotEmpty) {
            Get.back();
            Get.to(() => GallerySelectionPreviewScreen(
              selectedFilePaths: images.map((e) => e.path).toList(),
              chatController: controller,
            ));
          }
        },
        onAudioTap: () => controller.sendAudioAttachment(),
        onLocationTap: () =>
            Get.to(() => SendLocationScreen(chatController: controller)),
        onContactTap: () =>
            Get.to(() => SendContactScreen(chatController: controller)),
      ),
    );
  }

  Widget _buildImageBubble(
    MessageRealm message,
    bool isMe,
    BuildContext context,
    ChatDetailController controller,
  ) {
    final bool isWebUrl =
        (message.content!.content?.startsWith('http') ?? false) ||
        (message.content!.fileUrl?.startsWith('http') ?? false);
    final String path =
        message.content!.fileUrl ?? message.content!.content ?? '';

    return Obx(() {
      final isDownloaded = isMe || controller.isDownloaded(message.id);
      return GestureDetector(
        onTap: () {
          if (isDownloaded) {
            final isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov') || path.toLowerCase().contains('video');
            Get.to(() => MediaViewerScreen(
              message: message,
              isMe: isMe,
              chatController: controller,
              isVideo: isVideo,
            ));
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              isWebUrl
                  ? Image.network(
                      path,
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 50),
                    )
                  : Image.file(
                      File(path),
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 50),
                    ),
              if (!isDownloaded) ...[
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 250,
                    height: 250,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                GestureDetector(
                  onTap: () => controller.downloadAttachment(message.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.download,
                      color: ColorConstants.primaryBlue,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCallBubble(
    MessageRealm message,
    bool isMe,
    BuildContext context,
  ) {
    final String content = message.content?.content ?? '';
    String title = 'Video Call';
    String subtitle = '10 Sec';
    IconData icon = Icons.videocam;
    Color iconColor = Colors.greenAccent;

    if (content.toLowerCase().contains('missed')) {
      title = 'Missed Video Call';
      subtitle = '0 Sec';
      icon = Icons.phone_missed;
      iconColor = Colors.redAccent;
    } else if (content.toLowerCase().contains('voice') ||
        content.toLowerCase().contains('not answered')) {
      title = 'Voice Call';
      subtitle = 'Not answered';
      icon = Icons.phone_missed;
      iconColor = Colors.redAccent;
    } else if (content.toLowerCase().contains('group')) {
      title = 'Group Call';
      subtitle = '2 Invited';
      icon = Icons.group;
      iconColor = Colors.white;
    } else if (content.toLowerCase().contains('ongoing')) {
      title = 'Video Call';
      subtitle = 'Ongoing Call';
      icon = Icons.videocam;
      iconColor = Colors.greenAccent;
    } else {
      title = 'Video Call';
      subtitle = content.toLowerCase();
      icon = Icons.check;
      iconColor = Colors.greenAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildAudioBubble(
    MessageRealm message,
    bool isMe,
    BuildContext context,
    ChatDetailController controller,
  ) {
    return Obx(() {
      final isPlaying = controller.playingAudioId.value == message.id;
      final speed = controller.audioPlaybackSpeed.value;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => controller.togglePlayAudio(message.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: ColorConstants.primaryBlue,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          14,
                          (index) => Container(
                            width: 2.5,
                            height: isPlaying
                                ? ((index % 3 == 0) ? 20 : 12)
                                : ((index % 2 == 0) ? 8 : 16),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : ColorConstants.primaryBlue,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPlaying ? '00:05 Sec' : '00:30 Sec',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => controller.toggleAudioPlaybackSpeed(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      speed,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  message.content?.content ?? 'AUD123_2456.mp3',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  message.content?.size ?? '0.10 KB',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLocationBubble(
    MessageRealm message,
    bool isMe,
    BuildContext context,
    ChatDetailController controller,
  ) {
    final String content = message.content?.content ?? '';
    final bool isLive = content.contains('Live until');
    final bool isEnded = content.contains('ended');

    return Obx(() {
      final isActiveLive = controller.isLiveLocationActive(message.id);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(
                (isLive || isEnded || isActiveLive) ? 0 : 12,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=600&auto=format&fit=crop',
                  width: 240,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 240,
                    height: 150,
                    color: Colors.grey.shade300,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: ColorConstants.primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(
                          'https://i.pravatar.cc/150?img=8',
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: ColorConstants.primaryBlue,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isActiveLive || isLive)
            Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ColorConstants.inputBackground,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.radar,
                          color: Colors.blueAccent.shade200,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            content.contains('Live until')
                                ? content.split('\n').first
                                : 'Live until 5:18 pm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActiveLive)
                    GestureDetector(
                      onTap: () => controller.stopLiveLocation(message.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Stop sharing',
                          style: TextStyle(
                            color: ColorConstants.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else if (isEnded || (isLive && !isActiveLive))
            Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: ColorConstants.inputBackground,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: const Text(
                'Live location ended',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildContactBubble(
    MessageRealm message,
    bool isMe,
    BuildContext context,
  ) {
    final lines =
        (message.content?.content ?? 'Isabella Anderson\n+91 12345 67890')
            .split('\n');
    final name = lines.isNotEmpty ? lines[0] : 'Isabella Anderson';
    final phone = lines.length > 1 ? lines[1] : '+91 12345 67890';

    return Container(
      width: 240,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=$name'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Message',
              style: TextStyle(
                color: ColorConstants.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentBubble(
    MessageRealm message,
    bool isMe,
    BuildContext context,
    ChatDetailController controller,
  ) {
    return Obx(() {
      final isDownloaded = isMe || controller.isDownloaded(message.id);
      return SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=600&auto=format&fit=crop',
                    width: 240,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 240,
                      height: 120,
                      color: Colors.grey.shade300,
                    ),
                  ),
                  if (!isDownloaded) ...[
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 240,
                        height: 120,
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.downloadAttachment(message.id),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.download,
                          color: ColorConstants.primaryBlue,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : ColorConstants.inputBackground,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message.content?.content ?? 'File123.pdf',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    message.content?.size ?? '547.8 KB',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ChatDetailMenuItem extends StatelessWidget {
  const _ChatDetailMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Colors.white;

    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: danger ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedReactionBar extends StatelessWidget {
  const _SelectedReactionBar({required this.onReact});

  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    const reactions = ['😂', '😍', '😡', '😮', '😭', '😬'];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions
            .map(
              (emoji) => InkWell(
                onTap: () => onReact(emoji),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ReplyPreviewBar extends StatelessWidget {
  const _ReplyPreviewBar({
    required this.message,
    required this.senderName,
    required this.previewText,
    required this.onClose,
  });

  final MessageRealm message;
  final String senderName;
  final String previewText;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _imageProviderFor(message);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          left: BorderSide(color: ColorConstants.primaryBlue, width: 3),
        ),
      ),
      child: Row(
        children: [
          if (imageProvider != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image(
                image: imageProvider,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ColorConstants.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  ImageProvider? _imageProviderFor(MessageRealm message) {
    final content = message.content;
    if (content == null) return null;
    final isImage =
        content.type == 'image' ||
        (content.type == 'file' && content.fileType?.contains('image') == true);
    if (!isImage) return null;

    final path = content.fileUrl ?? content.content;
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) {
      return CachedNetworkImageProvider(path);
    }
    return FileImage(File(path));
  }
}
