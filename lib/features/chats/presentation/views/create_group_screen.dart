import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/color_constants.dart';
import '../controllers/create_group_controller.dart';
import 'add_group_members_screen.dart';
import 'chat_detail_screen.dart';

class CreateGroupScreen extends StatelessWidget {
  CreateGroupScreen({super.key});

  final CreateGroupController controller = Get.put(CreateGroupController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Create Group',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Center(
            child: GestureDetector(
              onTap: controller.pickPhoto,
              child: Obx(
                () => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 43,
                      backgroundColor: const Color(0xFFD7D7D7),
                      backgroundImage: controller.photoPath.value.isEmpty
                          ? null
                          : FileImage(File(controller.photoPath.value)),
                      child: controller.photoPath.value.isEmpty
                          ? const Icon(
                              Icons.image_outlined,
                              size: 38,
                              color: Color(0xFF555555),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: 2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF555555),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _LabelledField(
            label: 'Group Name',
            hint: 'Group Name',
            controller: controller.groupNameController,
          ),
          const SizedBox(height: 18),
          _LabelledField(
            label: 'About',
            hint: 'About',
            controller: controller.aboutController,
            maxLines: 4,
          ),
          const SizedBox(height: 18),
          _AddMembersTile(controller: controller),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Obx(
            () => SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: controller.isCreating.value
                    ? null
                    : () async {
                        final group = await controller.createGroup();
                        if (group == null) return;
                        Get.off(() => ChatDetailScreen(user: group));
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConstants.primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ColorConstants.primaryBlue
                      .withValues(alpha: 0.45),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: controller.isCreating.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Group',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: foregroundColor?.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddMembersTile extends StatelessWidget {
  const _AddMembersTile({required this.controller});

  final CreateGroupController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () =>
            Get.to(() => AddGroupMembersScreen(controller: controller)),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_1_outlined, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Add Members',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Obx(
                () => Text(
                  controller.selectedMemberIds.isEmpty
                      ? ''
                      : controller.selectedMemberIds.length.toString(),
                  style: TextStyle(
                    color: ColorConstants.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
