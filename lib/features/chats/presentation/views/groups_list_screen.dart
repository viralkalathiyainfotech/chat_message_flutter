import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/database/realm_helper.dart';
import '../../../../services/sync_service.dart';
import '../../../../utils/encryption_util.dart';
import '../controllers/groups_controller.dart';
import 'chat_detail_screen.dart';
import 'create_group_screen.dart';

class GroupsListScreen extends GetView<GroupsController> {
  GroupsListScreen({super.key}) {
    if (!Get.isRegistered<GroupsController>()) {
      Get.put(GroupsController());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Groups',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.groups.isEmpty) {
          return const Center(child: Text('No groups found.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.groups.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final UserRealm group = controller.groups[index];
            return _buildGroupItem(group, context);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => CreateGroupScreen());
        },
        backgroundColor: ColorConstants.primaryBlue,
        child: const Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupItem(UserRealm group, BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: group.photo != null && group.photo!.isNotEmpty
            ? CachedNetworkImageProvider(group.photo!)
            : null,
        child: group.photo == null || group.photo!.isEmpty
            ? const Icon(Icons.group, color: Colors.grey, size: 30)
            : null,
      ),
      title: Text(
        group.userName ?? 'Group',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Obx(() {
        controller.updateTrigger.value;
        final typingText = _formatGroupTypingText(
          Get.find<SyncService>().typingUserIdsByChat[group.id],
        );
        if (typingText.isNotEmpty) {
          return Text(
            typingText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ColorConstants.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          );
        }

        final lastMessage = RealmHelper().getLastMessageForUser(group.id);
        return Text(
          _groupSubtitle(group, lastMessage),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey),
        );
      }),
      trailing: Obx(() {
        controller.updateTrigger.value;
        final unreadCount = RealmHelper().getUnreadCountForUser(group.id);
        final lastMessage = RealmHelper().getLastMessageForUser(group.id);
        final timeText = lastMessage == null
            ? ''
            : _formatDate(lastMessage.createdAt);

        return Column(
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
                decoration: BoxDecoration(
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
        );
      }),
      onTap: () {
        Get.to(() => ChatDetailScreen(user: group));
      },
    );
  }

  String _groupSubtitle(UserRealm group, MessageRealm? lastMessage) {
    if (lastMessage == null) {
      return group.bio != null && group.bio!.isNotEmpty
          ? group.bio!
          : 'Group chat';
    }

    final sender = RealmHelper().realm.find<UserRealm>(lastMessage.senderId);
    final senderName = sender?.userName ?? 'Someone';
    final content = lastMessage.content;
    String messageText;
    if (content?.type == 'text') {
      messageText = EncryptionUtil.decrypt(content?.content ?? '');
    } else if (content?.type == 'image') {
      messageText = 'Photo';
    } else if (content?.type == 'call') {
      messageText = 'Call';
    } else {
      messageText = 'Attachment';
    }
    return '$senderName: $messageText';
  }

  String _formatGroupTypingText(List<String>? typingIds) {
    if (typingIds == null || typingIds.isEmpty) return '';
    if (typingIds.length == 1) {
      final user = RealmHelper().realm.find<UserRealm>(typingIds.first);
      return '${user?.userName ?? 'Someone'} is typing...';
    }
    return '${typingIds.length} are typing...';
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
}
