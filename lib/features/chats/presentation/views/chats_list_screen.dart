import 'package:chat_app/core/database/realm_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../../../../core/database/realm_helper.dart';
import '../../../../services/socket_service.dart';
import '../../../../services/sync_service.dart';
import '../../../../utils/encryption_util.dart';
import '../../../../core/widgets/animations/staggered_list_item.dart';
import '../controllers/chats_controller.dart';
import 'chat_camera_screen.dart';
import 'chat_detail_screen.dart';
import 'create_group_screen.dart';
import 'linked_devices_screen.dart';
import 'new_chat_screen.dart';

enum _ChatListMenuAction { newChat, newGroup, linkedDevices }

class ChatsListScreen extends StatelessWidget {
  ChatsListScreen({super.key});

  final ChatsController controller = Get.isRegistered<ChatsController>()
      ? Get.find<ChatsController>()
      : Get.put(ChatsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: .5),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          Obx(
            () => controller.isSyncing.value
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
                : const SizedBox.shrink(),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => Get.to(() => const ChatCameraScreen()),
          ),
          PopupMenuButton<_ChatListMenuAction>(
            icon: const Icon(Icons.more_vert),
            color: Theme.of(context).cardColor,
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ChatListMenuAction.newChat,
                child: _ChatListMenuItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'New chat',
                ),
              ),
              PopupMenuItem(
                value: _ChatListMenuAction.newGroup,
                child: _ChatListMenuItem(
                  icon: Icons.group_add_outlined,
                  label: 'New group',
                ),
              ),
              PopupMenuItem(
                value: _ChatListMenuAction.linkedDevices,
                child: _ChatListMenuItem(
                  icon: Icons.devices_outlined,
                  label: 'Linked devices',
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            GestureDetector(
              onTap: controller.toggleArchiveView,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    controller.chatListTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.swap_vert_rounded, size: 22),
                ],
              ).paddingAll(20),
            ),
            if (controller.recentChats.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    controller.emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: controller.recentChats.length,
                  itemBuilder: (context, index) {
                    final UserRealm chat = controller.recentChats[index];
                    return StaggeredListItem(
                      index: index,
                      child: _buildChatItem(chat, context),
                    );
                  },
                ),
              ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => NewChatScreen());
        },
        backgroundColor: ColorConstants.primaryBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildChatItem(UserRealm chat, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Get.to(() => ChatDetailScreen(user: chat));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: chat.photo != null
                        ? CachedNetworkImageProvider(chat.photo!)
                        : null,
                    child: chat.photo == null
                        ? Icon(
                            chat.isGroup == true ? Icons.group : Icons.person,
                          )
                        : null,
                  ),
                  Obx(() {
                    final isOnline = Get.find<SocketService>().onlineUsers
                        .contains(chat.id);

                    if (!isOnline) return const SizedBox.shrink();

                    return Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ColorConstants.white,
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.userName ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Obx(() {
                      controller.updateTrigger.value;

                      final unreadCount = RealmHelper().getUnreadCountForUser(
                        chat.id,
                      );

                      final lastMessage = RealmHelper().getLastMessageForUser(
                        chat.id,
                      );

                      String subtitleText = 'Tap to chat...';

                      if (lastMessage != null) {
                        final content = lastMessage.content;

                        if (content?.type == 'text') {
                          subtitleText = EncryptionUtil.decrypt(
                            content?.content ?? '',
                          );
                        } else if (content?.type == 'image') {
                          subtitleText = '📷 Photo';
                        } else if (content?.type == 'call') {
                          subtitleText = '📞 Call';
                        } else if (content?.type == 'video') {
                          subtitleText = '🎥 Video';
                        } else if (content?.type == 'audio') {
                          subtitleText = '🎵 Audio';
                        } else {
                          subtitleText = '📎 Attachment';
                        }
                      }

                      final syncService = Get.find<SyncService>();

                      final typingText = chat.isGroup == true
                          ? _formatGroupTypingText(
                              syncService.typingUserIdsByChat[chat.id],
                            )
                          : syncService.typingUsers[chat.id] == true
                          ? 'typing...'
                          : '';

                      if (typingText.isNotEmpty) {
                        return Text(
                          typingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ColorConstants.primaryBlue,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        );
                      }

                      return Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? ColorConstants.white
                              : ColorConstants.white.withValues(alpha: 0.5),
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Obx(() {
                controller.updateTrigger.value;

                final unreadCount = RealmHelper().getUnreadCountForUser(
                  chat.id,
                );

                final lastMessage = RealmHelper().getLastMessageForUser(
                  chat.id,
                );

                final timeText = lastMessage != null
                    ? _formatDate(lastMessage.createdAt)
                    : '';

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        color: ColorConstants.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        height: 20,
                        width: 20,
                        decoration: BoxDecoration(
                          color: ColorConstants.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: ColorConstants.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(_ChatListMenuAction action) {
    switch (action) {
      case _ChatListMenuAction.newChat:
        Get.to(() => NewChatScreen());
        break;
      case _ChatListMenuAction.newGroup:
        Get.to(() => CreateGroupScreen());
        break;
      case _ChatListMenuAction.linkedDevices:
        Get.to(() => LinkedDevicesScreen());
        break;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0 && now.day == date.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 ||
        (difference.inDays == 0 && now.day != date.day)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  String _formatGroupTypingText(List<String>? typingIds) {
    if (typingIds == null || typingIds.isEmpty) return '';
    if (typingIds.length == 1) {
      final user = RealmHelper().realm.find<UserRealm>(typingIds.first);
      return '${user?.userName ?? 'Someone'} is typing...';
    }
    return '${typingIds.length} are typing...';
  }
}

class _ChatListMenuItem extends StatelessWidget {
  const _ChatListMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodyMedium?.color;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
