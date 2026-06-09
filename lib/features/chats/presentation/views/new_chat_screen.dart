import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../constants/color_constants.dart';
import '../controllers/new_chat_controller.dart';
import 'chat_detail_screen.dart';

class NewChatScreen extends StatelessWidget {
  NewChatScreen({super.key});

  final NewChatController controller = Get.put(NewChatController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: controller.searchController,
                decoration: const InputDecoration(
                  hintText: 'Search user...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildActionItem(
                  context, 
                  icon: Icons.group_add, 
                  title: 'New Group', 
                  onTap: () {
                    // TODO: Implement New Group
                  }
                ),
                _buildActionItem(
                  context, 
                  icon: Icons.person_add, 
                  title: 'New Contact', 
                  onTap: () {
                    // TODO: Implement New Contact
                  }
                ),
                _buildActionItem(
                  context, 
                  icon: Icons.groups, 
                  title: 'New Community', 
                  onTap: () {
                    // TODO: Implement New Community
                  }
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Contacts on App',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            if (controller.isLoading.value) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (controller.searchResults.isEmpty) {
              return const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = controller.searchResults[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundImage: user.photo != null ? CachedNetworkImageProvider(user.photo!) : null,
                      backgroundColor: Colors.grey.shade400,
                      child: user.photo == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    title: Text(
                      user.userName ?? 'Unknown User',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      user.bio ?? user.mobileNumber ?? 'Available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Get.off(() => ChatDetailScreen(user: user));
                    },
                  );
                },
                childCount: controller.searchResults.length,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: ColorConstants.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
