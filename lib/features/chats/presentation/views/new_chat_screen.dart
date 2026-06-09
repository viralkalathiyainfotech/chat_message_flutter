import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.searchResults.isEmpty && controller.unregisteredContacts.isEmpty) {
          return const Center(
            child: Text(
              'No contacts found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            if (controller.searchResults.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Contacts on ChatApp', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = controller.searchResults[index];
                    final hasValidPhoto = user.photo != null && user.photo!.startsWith('http');
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundImage: hasValidPhoto ? CachedNetworkImageProvider(user.photo!) : null,
                        backgroundColor: Colors.grey.shade400,
                        child: !hasValidPhoto ? const Icon(Icons.person, color: Colors.white) : null,
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
              ),
            ],
            
            if (controller.unregisteredContacts.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('Invite to ChatApp', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final contact = controller.unregisteredContacts[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blueGrey.shade100,
                        child: Text(
                          contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                          style: TextStyle(color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        contact.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      subtitle: Text(
                        contact.phoneNumber,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          // Handle invite action
                          Get.snackbar('Invite', 'Inviting ${contact.displayName} via SMS...');
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          foregroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                  childCount: controller.unregisteredContacts.length,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

}
