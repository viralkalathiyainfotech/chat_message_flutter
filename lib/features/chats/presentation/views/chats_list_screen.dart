import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/extensions/app_extensions.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/chats_controller.dart';
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';

class ChatsListScreen extends StatelessWidget {
  ChatsListScreen({super.key});

  final ChatsController controller = Get.put(ChatsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Chats', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: .5),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.recentChats.isEmpty) {
          return const Center(
            child: Text(
              'No chats yet.\\nStart a conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.recentChats.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final chat = controller.recentChats[index];
            return _buildChatItem(chat, context);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => NewChatScreen());
        },
        backgroundColor: ColorConstants.primaryBlue,
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildChatItem(dynamic chat, BuildContext context) {
    // We will update this when we have the real model, for now use standard chat item
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: chat.photo != null
                ? CachedNetworkImageProvider(chat.photo!)
                : null,
            child: chat.photo == null ? const Icon(Icons.person) : null,
          ),
          if (chat.isOnline == true)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chat.userName ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        'Tap to chat...', // placeholder
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '12:00 PM', // placeholder
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          4.height,
          // Unread badge placeholder
          // Container(
          //   padding: const EdgeInsets.all(6),
          //   decoration: const BoxDecoration(
          //     color: ColorConstants.primaryBlue,
          //     shape: BoxShape.circle,
          //   ),
          //   child: const Text(
          //     '2',
          //     style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          //   ),
          // ),
        ],
      ),
      onTap: () {
        Get.to(() => ChatDetailScreen(user: chat));
      },
    );
  }
}
