import 'package:chat_app/core/database/realm_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../../../../core/database/realm_helper.dart';
import '../../../../services/socket_service.dart';
import '../../../../utils/encryption_util.dart';
import '../../../../core/widgets/animations/staggered_list_item.dart';
import '../../../../core/widgets/animations/pulsing_widget.dart';
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
          Obx(() => controller.isSyncing.value
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
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
            final UserRealm chat = controller.recentChats[index];
            return StaggeredListItem(
              index: index,
              child: _buildChatItem(chat, context),
            );
          },
        );
      }),
      floatingActionButton: PulsingWidget(
        scaleBegin: 1.0,
        scaleEnd: 1.05,
        duration: const Duration(milliseconds: 2000),
        child: FloatingActionButton(
          onPressed: () {
            Get.to(() => NewChatScreen());
          },
          backgroundColor: ColorConstants.primaryBlue,
          child: const Icon(Icons.message, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildChatItem(UserRealm chat, BuildContext context) {
    MessageRealm? lastMessage = RealmHelper().getLastMessageForUser(chat.id);
    int unreadCount = RealmHelper().realm.query<MessageRealm>("senderId == \$0 AND status != 'read'", [chat.id]).length;
        String subtitleText = 'Tap to chat...';
        String timeText = '';
        
        if (lastMessage != null) {
          final content = lastMessage.content;
          if (content?.type == 'text') {
            subtitleText = EncryptionUtil.decrypt(content?.content ?? '');
          } else if (content?.type == 'image') {
            subtitleText = '📷 Photo';
          } else if (content?.type == 'call') {
            subtitleText = '📞 Call';
          } else {
            subtitleText = '📎 Attachment';
          }
          
          timeText = _formatDate(lastMessage.createdAt);
        }

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
              Obx(() {
                final isOnline = Get.find<SocketService>().onlineUsers.contains(chat.id);
                if (isOnline) {
                  return Positioned(
                    right: 0,
                    bottom: 0,
                    child: PulsingWidget(
                      scaleBegin: 0.8,
                      scaleEnd: 1.2,
                      duration: const Duration(milliseconds: 800),
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
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
          title: Text(
            chat.userName ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeText,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 4),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: ColorConstants.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            Get.to(() => ChatDetailScreen(user: chat));
          },
        );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0 && now.day == date.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != date.day)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
}
