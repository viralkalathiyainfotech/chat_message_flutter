import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/color_constants.dart';
import '../../../../core/database/realm_models.dart';
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
        leading: Obx(
          () => IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: controller.isSearching.value
                ? controller.stopSearch
                : Get.back,
          ),
        ),
        titleSpacing: 0,
        title: Obx(
          () => controller.isSearching.value
              ? _SearchField(controller: controller.searchController)
              : const Text(
                  'Select Contact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
        actions: [
          Obx(
            () => controller.isSearching.value
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: controller.startSearch,
                  ),
          ),
        ],
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.searchResults.isEmpty &&
            controller.unregisteredContacts.isEmpty) {
          return const Center(
            child: Text(
              'No contacts found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            if (controller.searchResults.isNotEmpty) ...[
              const _SectionTitle('All users'),
              const SizedBox(height: 8),
              ...controller.searchResults.map(
                (user) => _ContactTile(
                  user: user,
                  onTap: () => Get.off(() => ChatDetailScreen(user: user)),
                ),
              ),
            ],
            if (controller.unregisteredContacts.isNotEmpty) ...[
              const SizedBox(height: 10),
              const _SectionTitle('Invite'),
              const SizedBox(height: 8),
              ...controller.unregisteredContacts.map(
                (contact) => _InviteTile(contact: contact),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search users...',
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(
          context,
        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.user, required this.onTap});

  final UserRealm user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValidPhoto = user.photo != null && user.photo!.startsWith('http');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundImage: hasValidPhoto
                      ? CachedNetworkImageProvider(user.photo!)
                      : null,
                  backgroundColor: Colors.grey.shade400,
                  child: hasValidPhoto
                      ? null
                      : const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.userName ?? 'Unknown User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.contact});

  final LocalContactRealm contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFFFC928),
              child: Text(
                contact.displayName.isNotEmpty
                    ? contact.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                contact.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Get.snackbar('Invite', 'Inviting ${contact.displayName}...'),
              style: TextButton.styleFrom(
                minimumSize: const Size(54, 28),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: ColorConstants.primaryBlue,
                foregroundColor: Colors.white,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '+Invite',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
