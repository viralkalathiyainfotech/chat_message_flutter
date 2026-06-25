import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/profile_controller.dart';

class InviteFriendScreen extends StatelessWidget {
  InviteFriendScreen({super.key});

  final ProfileController controller = Get.find<ProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Invite a friend',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Obx(
          () => controller.inviteContacts.isEmpty
              ? const Center(
                  child: Text(
                    'No contacts available',
                    style: TextStyle(color: ColorConstants.textSecondary, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  itemCount: controller.inviteContacts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final contact = controller.inviteContacts[index];
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFD9D9D9),
                          backgroundImage: (contact['avatar'] != null && contact['avatar']!.isNotEmpty)
                              ? CachedNetworkImageProvider(contact['avatar']!)
                              : null,
                          child: (contact['avatar'] == null || contact['avatar']!.isEmpty)
                              ? const Icon(Icons.person, color: ColorConstants.textSecondary)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contact['phone'] ?? '',
                                style: const TextStyle(
                                  color: ColorConstants.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Get.snackbar(
                              'Invitation Sent',
                              'An invitation has been sent to ${contact['name']}',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: ColorConstants.inputBackground,
                              colorText: Colors.white,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: ColorConstants.inputBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: ColorConstants.primaryBlue.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '+Invite',
                              style: TextStyle(
                                color: ColorConstants.primaryBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
