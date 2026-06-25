import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/privacy_controller.dart';
import 'blocked_contacts_screen.dart';

class PrivacyScreen extends StatelessWidget {
  PrivacyScreen({super.key});

  final PrivacyController controller = Get.find<PrivacyController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Privacy',
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
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorConstants.inputBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildPrivacyTile(
                        title: 'Profile photo',
                        value: controller.profilePhotoPrivacy.value,
                        onTap: () => _showPrivacyBottomSheet(
                          context: context,
                          title: 'Profile photo',
                          currentValue: controller.profilePhotoPrivacy.value,
                          onSelected: controller.updateProfilePhotoPrivacy,
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15), indent: 20, endIndent: 20),
                      _buildPrivacyTile(
                        title: 'Group',
                        value: controller.groupToJoinPrivacy.value,
                        onTap: () => _showPrivacyBottomSheet(
                          context: context,
                          title: 'Group',
                          currentValue: controller.groupToJoinPrivacy.value,
                          onSelected: controller.updateGroupToJoinPrivacy,
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15), indent: 20, endIndent: 20),
                      _buildPrivacyTile(
                        title: 'Blocked Contacts',
                        value: '${controller.blockedContacts.length}',
                        onTap: () => Get.to(() => BlockedContactsScreen()),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildPrivacyTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: ColorConstants.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: ColorConstants.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyBottomSheet({
    required BuildContext context,
    required String title,
    required String currentValue,
    required Function(String) onSelected,
  }) {
    final options = ['Everyone', 'My Contacts', 'Nobody'];
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorConstants.inputBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((option) {
                final isSelected = currentValue == option;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      onSelected(option);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          option,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? ColorConstants.primaryBlue : ColorConstants.textSecondary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
