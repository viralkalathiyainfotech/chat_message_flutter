import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../constants/color_constants.dart';
import '../../../../constants/asset_constants.dart';
import '../../../../core/database/realm_models.dart';
import '../controllers/chat_detail_controller.dart';
import '../widgets/attachment_bottom_sheet.dart';

class ChatDetailScreen extends StatelessWidget {
  final UserRealm user;
  
  const ChatDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Inject controller specific to this user
    final controller = Get.put(ChatDetailController(remoteUser: user), tag: user.id);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, controller),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(controller),
          ),
          _buildInputBar(context, controller),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ChatDetailController controller) {
    return AppBar(
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leadingWidth: 30,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: user.photo != null ? CachedNetworkImageProvider(user.photo!) : null,
            child: user.photo == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.userName ?? 'User',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Obx(() {
                  if (controller.isRemoteTyping.value) {
                    return const Text('typing...', style: TextStyle(fontSize: 12, color: ColorConstants.primaryBlue));
                  }
                  return Text(
                    user.isOnline == true ? 'Online' : 'Offline',
                    style: TextStyle(fontSize: 12, color: user.isOnline == true ? Colors.green : Colors.grey),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call), onPressed: () {}),
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
        return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.grey)));
      }
      return ListView.builder(
        reverse: true, // start from bottom
        controller: controller.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          final isMe = message.senderId != controller.remoteUser.id; // Check if sent by current user
          
          return _buildChatBubble(message, isMe, context);
        },
      );
    });
  }

  Widget _buildChatBubble(MessageRealm message, bool isMe, BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? ColorConstants.primaryBlue : Theme.of(context).cardColor,
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
                message.content?.content ?? '',
                style: TextStyle(
                  color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 15,
                ),
              )
            else if (message.content?.type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(message.content!.content!), width: 200, height: 200, fit: BoxFit.cover),
              )
            else
              Text('Attachment: ${message.content?.type}', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
            
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isPending ? Icons.access_time : Icons.done_all,
                    size: 14,
                    color: message.status == 'read' ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatDetailController controller) {
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
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
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
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: SvgPicture.asset(AssetConstants.attachmentsIcon, colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn)),
                      onPressed: () => _showAttachmentMenu(context, controller),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final isTyping = controller.isTyping.value;
              return GestureDetector(
                onTap: () {
                  if (isTyping) {
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
                  child: isTyping
                      ? const Icon(Icons.send, color: Colors.white, size: 20)
                      : SvgPicture.asset(AssetConstants.micIcon, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), fit: BoxFit.scaleDown),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context, ChatDetailController controller) {
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
          final XFile? image = await picker.pickImage(source: ImageSource.camera);
          if (image != null) {
            controller.sendAttachment(image.path, 'image', '');
          }
        },
        onGalleryTap: () async {
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
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
}
