import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../constants/color_constants.dart';
import '../../../../constants/asset_constants.dart';
import '../../../call/presentation/controllers/call_controller.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../utils/encryption_util.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/widgets/animations/animated_chat_bubble.dart';
import '../../../../services/sync_service.dart';
import '../controllers/chat_detail_controller.dart';
import '../widgets/attachment_bottom_sheet.dart';

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
    final user = widget.user;
    return AppBar(
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leadingWidth: 50,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: user.photo != null
                ? CachedNetworkImageProvider(user.photo!)
                : null,
            child: user.photo == null ? const Icon(Icons.person) : null,
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
                    return const Text(
                      'typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorConstants.primaryBlue,
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
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () => Get.find<CallController>().startCall(
            controller.remoteUser.id,
            video: true,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () => Get.find<CallController>().startCall(
            controller.remoteUser.id,
            video: false,
          ),
        ),
        IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
      ],
    );
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
            needsExtraTopPadding,
            context,
            controller,
          );
        },
      );
    });
  }

  Widget _buildChatBubble(
    MessageRealm message,
    bool isMe,
    bool needsExtraTopPadding,
    BuildContext context,
    ChatDetailController controller,
  ) {
    return AnimatedChatBubble(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context, controller, message, isMe),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Time above the bubble
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMe) ...[
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
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
                            : (message.status == 'sent' ? Icons.done : Icons.done_all),
                          size: 14,
                          color: message.status == 'read' ? Colors.lightBlueAccent : Colors.grey,
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
                  padding: (message.content?.type == 'image' || message.content?.type == 'location')
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: (message.content?.type == 'call')
                        ? Theme.of(context).cardColor
                        : (isMe ? ColorConstants.primaryBlue : Theme.of(context).cardColor),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(16),
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
                          EncryptionUtil.decrypt(message.content?.content ?? ''),
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 15,
                          ),
                        )
                      else if (message.content?.type == 'image' || (message.content?.type == 'file' && (message.content?.fileType?.contains('image') ?? false)))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (message.content!.content?.startsWith('http') ?? false) || (message.content!.fileUrl?.startsWith('http') ?? false)
                              ? Image.network(
                                  message.content!.fileUrl ?? message.content!.content!,
                                  width: 250,
                                  height: 250,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                                )
                              : Image.file(
                                  File(message.content!.content ?? ''),
                                  width: 250,
                                  height: 250,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                                ),
                        )
                      else if (message.content?.type == 'call')
                        _buildCallBubble(message, isMe, context)
                      else if (message.content?.type == 'location')
                        _buildLocationBubble(message, isMe, context)
                      else if (message.content?.type == 'contact')
                        _buildContactBubble(message, isMe, context)
                      else if (message.content?.type == 'file' && (message.content?.fileType?.contains('audio') ?? false))
                        _buildAudioBubble(message, isMe, context)
                      else if (message.content?.type == 'file')
                        _buildDocumentBubble(message, isMe, context)
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
                            color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
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
                        message.reactions.map((r) => r.emoji).toSet().join(' '),
                        style: const TextStyle(fontSize: 14, height: 1.1),
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
    ));
  }

  void _showMessageOptions(
    BuildContext context,
    ChatDetailController controller,
    MessageRealm message,
    bool isMe,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 24, top: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '👏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Get.back();
                      controller.reactToMessage(message.id, emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            if (isMe && message.content?.type == 'text')
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Message'),
                onTap: () {
                  Get.back();
                  controller.editMessage(message);
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Get.back();
                  controller.deleteMessage(message.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () {
                // Clipboard.setData(ClipboardData(text: EncryptionUtil.decrypt(message.content?.content ?? '')));
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatDetailController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        Container(
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
                        // Start audio recording logic
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
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
        ),
      ],
    );
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
            // controller.sendAttachment(result.files.single.path!, 'document', result.files.single.size.toString());
          }
        },
        onCameraTap: () async {
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: ImageSource.camera,
          );
          if (image != null) {
            controller.sendAttachment(image.path, 'image', '');
          }
        },
        onGalleryTap: () async {
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: ImageSource.gallery,
          );
          if (image != null) {
            controller.sendAttachment(image.path, 'image', '');
          }
        },
        onAudioTap: () {},
        onLocationTap: () {},
        onContactTap: () {},
      ),
    );
  }

  Widget _buildCallBubble(MessageRealm message, bool isMe, BuildContext context) {
    final isVideo = message.content?.callType == 'video';
    
    // Fallback logic for duration based on call status
    String displayDuration = message.content?.duration ?? '0 Sec';
    if (displayDuration == 'Unknown' || displayDuration.isEmpty) {
       displayDuration = (message.content?.status == 'missed' || message.content?.status == 'rejected') ? '0 Sec' : 'Ongoing';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: message.content?.status == 'missed' ? Colors.redAccent : Colors.lightGreenAccent,
              width: 1.5,
            ),
          ),
          child: Icon(
            isVideo 
                ? (message.content?.status == 'missed' ? Icons.videocam_off : Icons.videocam)
                : (message.content?.status == 'missed' ? Icons.phone_missed : Icons.phone_in_talk),
            color: message.content?.status == 'missed' ? Colors.redAccent : Colors.lightGreenAccent,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${message.content?.status == 'missed' ? 'Missed' : 'Ended'} ${isVideo ? 'Video' : 'Voice'} Call',
              style: const TextStyle(
                color: Colors.white, // Since bubble background is always dark cardColor
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  displayDuration,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioBubble(MessageRealm message, bool isMe, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_fill, color: isMe ? Colors.white : Get.theme.primaryColor, size: 40),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 30,
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          // Waveform placeholder
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(10, (index) => Container(
              width: 3,
              height: (index % 2 == 0) ? 10 : 20,
              color: isMe ? Colors.white : Get.theme.primaryColor,
            )),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          message.content?.duration ?? '0:00',
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        )
      ],
    );
  }

  Widget _buildLocationBubble(MessageRealm message, bool isMe, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 200,
            height: 120,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Location',
          style: TextStyle(color: isMe ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildContactBubble(MessageRealm message, bool isMe, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content?.content ?? 'Contact',
              style: TextStyle(color: isMe ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to view',
              style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentBubble(MessageRealm message, bool isMe, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : Get.theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Get.theme.primaryColor),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content?.content ?? 'Document',
                style: TextStyle(color: isMe ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                message.content?.size ?? '',
                style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
