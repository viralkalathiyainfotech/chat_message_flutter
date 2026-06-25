import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/privacy_controller.dart';

class BlockedContactsScreen extends StatelessWidget {
  BlockedContactsScreen({super.key});

  final PrivacyController controller = Get.find<PrivacyController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Blocked Contacts',
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
          () => Stack(
            children: [
              controller.blockedContacts.isEmpty
                  ? const Center(
                      child: Text(
                        'No blocked contacts',
                        style: TextStyle(color: ColorConstants.textSecondary, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      itemCount: controller.blockedContacts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final contact = controller.blockedContacts[index];
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
                              onTap: () => _showUnblockDialog(context, contact['id'] ?? '', contact['name'] ?? ''),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: ColorConstants.inputBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'Unblock',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
              if (controller.isLoading.value)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ColorConstants.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnblockDialog(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: ColorConstants.inputBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unblock $name?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '$name will be able to call you or send you messages.',
                  style: const TextStyle(
                    color: ColorConstants.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          controller.unblockContact(id, name);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorConstants.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Unblock',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
