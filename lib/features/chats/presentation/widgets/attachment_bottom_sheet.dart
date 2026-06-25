import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../constants/color_constants.dart';
import '../../../../theme/app_colors.dart';

class AttachmentBottomSheet extends StatelessWidget {
  final VoidCallback onDocumentTap;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onAudioTap;
  final VoidCallback onLocationTap;
  final VoidCallback onContactTap;

  const AttachmentBottomSheet({
    super.key,
    required this.onDocumentTap,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onAudioTap,
    required this.onLocationTap,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: ColorConstants.inputBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAttachmentItem(
                context,
                icon: Icons.insert_photo,
                bgColor: AppColors.primary(context),
                iconColor: Colors.white,
                label: 'Gallery',
                onTap: onGalleryTap,
              ),
              _buildAttachmentItem(
                context,
                icon: Icons.camera_alt,
                bgColor: AppColors.primary(context),
                iconColor: Colors.white,
                label: 'Camera',
                onTap: onCameraTap,
              ),
              _buildAttachmentItem(
                context,
                icon: Icons.location_on,
                bgColor: const Color(0xFF2C2C2C),
                iconColor: Colors.greenAccent,
                label: 'Location',
                onTap: onLocationTap,
              ),
              _buildAttachmentItem(
                context,
                icon: Icons.person,
                bgColor: const Color(0xFF2C2C2C),
                iconColor: Colors.lightBlueAccent,
                label: 'Contact',
                onTap: onContactTap,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildAttachmentItem(
                context,
                icon: Icons.description,
                bgColor: const Color(0xFF2C2C2C),
                iconColor: Colors.blueAccent,
                label: 'Docs',
                onTap: onDocumentTap,
              ),
              const SizedBox(width: 32),
              _buildAttachmentItem(
                context,
                icon: Icons.headphones,
                bgColor: const Color(0xFF2C2C2C),
                iconColor: Colors.pinkAccent,
                label: 'Audio',
                onTap: onAudioTap,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(
    BuildContext context, {
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Get.back(); // close bottom sheet
        onTap();
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
