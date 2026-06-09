import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAttachmentItem(
                context,
                icon: Icons.insert_drive_file,
                color: Colors.indigo,
                label: 'Document',
                onTap: onDocumentTap,
              ),
              _buildAttachmentItem(
                context,
                icon: Icons.camera_alt,
                color: Colors.pink,
                label: 'Camera',
                onTap: onCameraTap,
              ),
              _buildAttachmentItem(
                context,
                icon: Icons.insert_photo,
                color: Colors.purple,
                label: 'Gallery',
                onTap: onGalleryTap,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAttachmentItem(
                context,
                icon: Icons.headphones,
                color: Colors.orange,
                label: 'Audio',
                onTap: onAudioTap,
              ),
              _buildAttachmentItem(
                context,
                icon: Icons.location_on,
                color: Colors.green,
                label: 'Location',
                onTap: onLocationTap,
              ),
              _buildAttachmentItem(
                context,
                icon: Icons.person,
                color: Colors.blue,
                label: 'Contact',
                onTap: onContactTap,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(BuildContext context, {required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        Get.back(); // close bottom sheet
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
