import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../../../../core/database/realm_models.dart';
import '../controllers/groups_controller.dart';
import 'chat_detail_screen.dart';

class GroupsListScreen extends GetView<GroupsController> {
  GroupsListScreen({super.key}) {
    Get.put(GroupsController());
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
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.groups.isEmpty) {
          return const Center(child: Text('No groups found.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.groups.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final UserRealm group = controller.groups[index];
            return _buildGroupItem(group, context);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: Create new group
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
      subtitle: Text(
        group.bio != null && group.bio!.isNotEmpty ? group.bio! : 'Group chat',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey),
      ),
      onTap: () {
        Get.to(() => ChatDetailScreen(user: group));
      },
    );
  }
}
