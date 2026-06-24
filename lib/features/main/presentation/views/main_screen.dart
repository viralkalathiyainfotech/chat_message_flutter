import 'package:flutter/material.dart';
import 'package:get/get.dart' hide ContextExtensionss;
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../constants/asset_constants.dart';
import '../../../../../constants/color_constants.dart';
import '../../../../core/extensions/app_extensions.dart';
import '../../../chats/presentation/views/chats_list_screen.dart';
import '../../../chats/presentation/views/groups_list_screen.dart';
import '../../../calls/presentation/views/calls_list_screen.dart';
import '../../../profile/presentation/views/profile_screen.dart';
import '../controllers/main_controller.dart';

class MainScreen extends GetView<MainController> {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.currentIndex.value,
          children: [
            ChatsListScreen(),
            GroupsListScreen(),
            CallsListScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(controller: controller),
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final MainController controller;

  const CustomBottomNavBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = context.isDarkMode;

    return Container(
      // padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, AssetConstants.chatsIcon, 'Chats', context),
              _buildNavItem(1, AssetConstants.groupsIcon, 'Groups', context),
              _buildNavItem(2, AssetConstants.callsIcon, 'Calls', context),
              _buildNavItem(3, AssetConstants.profileIcon, 'Profile', context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String iconPath,
    String label,
    BuildContext context,
  ) {
    final isSelected = controller.currentIndex.value == index;
    final theme = context.theme;

    return GestureDetector(
      onTap: () => controller.changePage(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 12.0,
          vertical: 8.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              iconPath,
              colorFilter: ColorFilter.mode(
                isSelected
                    ? ColorConstants.primaryBlue
                    : theme.bottomNavigationBarTheme.unselectedItemColor ??
                          const Color(0X66FFFFFF),
                BlendMode.srcIn,
              ),
              height: 24,
              width: 24,
            ),
            4.height,
            Text(label,style: TextStyle(
                color: isSelected
                    ? ColorConstants.primaryBlue
                    : theme.bottomNavigationBarTheme.unselectedItemColor ??
                          const Color(0X66FFFFFF),
                fontWeight: FontWeight.w500,
                fontSize: 12,
                fontFamily: 'Inter',
              ),),
          ],
        ),
      ),
    );
  }
}
