import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/profile_controller.dart';
import 'privacy_screen.dart';
import 'personal_info_screen.dart';
import 'qr_code_screen.dart';
import 'theme_screen.dart';
import 'invite_friend_screen.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final ProfileController controller = Get.find<ProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: ColorConstants.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Obx(() {
                  final user = controller.currentUser.value;
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFD9D9D9),
                        backgroundImage:
                            (user?.photo != null && user!.photo!.isNotEmpty)
                            ? CachedNetworkImageProvider(user.photo!)
                            : null,
                        child: (user?.photo == null || user!.photo!.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 32,
                                color: ColorConstants.textSecondary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.userName ?? 'Wade Warmen',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (user?.mobileNumber != null &&
                                      user!.mobileNumber!.isNotEmpty)
                                  ? user.mobileNumber!
                                  : '+91 85320 59232',
                              style: const TextStyle(
                                color: ColorConstants.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Get.to(() => QrCodeScreen()),
                        child: Icon(
                          Icons.qr_code,
                          color: ColorConstants.primaryBlue,
                          size: 28,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 28),
              const Text(
                'Settings',
                style: TextStyle(
                  color: ColorConstants.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              // Settings Tiles
              _buildSettingTile(
                icon: Icons.person_outline,
                title: 'Personal Info',
                onTap: () => Get.to(() => PersonalInfoScreen()),
              ),
              _buildSettingTile(
                icon: Icons.wb_sunny_outlined,
                title: 'Theme',
                onTap: () => Get.to(() => ThemeScreen()),
              ),
              _buildSettingTile(
                icon: Icons.lock_outline,
                title: 'Privacy',
                onTap: () => Get.to(() => PrivacyScreen()),
              ),
              _buildSettingTile(
                icon: Icons.notifications_none,
                title: 'Notifications',
                trailing: Obx(
                  () => Switch(
                    padding: EdgeInsets.zero,
                    value: controller.notificationsEnabled.value,
                    onChanged: (val) => controller.toggleNotifications(val),
                    activeThumbColor: ColorConstants.white,
                    activeTrackColor: ColorConstants.primaryBlue,
                  ),
                ),
              ),
              _buildSettingTile(
                icon: Icons.group_outlined,
                title: 'Invite a friend',
                onTap: () => Get.to(() => InviteFriendScreen()),
              ),
              _buildSettingTile(
                icon: Icons.star_outline,
                title: 'Rate us',
                onTap: () =>
                    Get.snackbar('Rate us', 'Thank you for your feedback!'),
              ),
              _buildSettingTile(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                onTap: () =>
                    Get.snackbar('Privacy Policy', 'Opening Privacy Policy'),
              ),
              const SizedBox(height: 40),
              // Logout Button
              Center(
                child: GestureDetector(
                  onTap: () => controller.logout(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.power_settings_new,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Version Number
              const Center(
                child: Text(
                  'v24.11.1',
                  style: TextStyle(
                    color: ColorConstants.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: ColorConstants.inputBackground,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Row(
              children: [
                Icon(icon, color: ColorConstants.primaryBlue, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
