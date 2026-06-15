import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../../../../services/storage_service.dart';
import '../controllers/calls_controller.dart';
import '../../../chats/presentation/views/chat_detail_screen.dart';

class CallsListScreen extends GetView<CallsController> {
  CallsListScreen({super.key}) {
    Get.put(CallsController());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Calls',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black, 
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.calls.isEmpty) {
          return const Center(child: Text('No call history.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.calls.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            final callRecord = controller.calls[index];
            return _buildCallItem(callRecord, context);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: Start new call
        },
        backgroundColor: ColorConstants.primaryBlue,
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
    );
  }

  Widget _buildCallItem(CallRecord record, BuildContext context) {
    final user = record.user;
    final message = record.message;
    final content = message.content;
    
    final myUserId = Get.find<StorageService>().getUserId() ?? '';
    final isOutgoing = message.senderId == myUserId;
    final isVideo = content?.callType == 'video';
    
    // Parse timestamp safely
    String timeString = '';
    if (content?.timestamp != null) {
       final dt = DateTime.tryParse(content!.timestamp!);
       if (dt != null) {
          timeString = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
       } else {
          timeString = message.createdAt.toString().substring(11, 16);
       }
    } else {
       timeString = message.createdAt.toString().substring(11, 16);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: user.photo != null && user.photo!.isNotEmpty
            ? CachedNetworkImageProvider(user.photo!)
            : null,
        child: user.photo == null || user.photo!.isEmpty
            ? Icon(user.isGroup == true ? Icons.group : Icons.person, color: Colors.grey, size: 30)
            : null,
      ),
      title: Text(
        user.userName ?? 'User',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Row(
        children: [
          Icon(
            isOutgoing ? Icons.call_made : Icons.call_received,
            size: 16,
            color: isOutgoing ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            timeString,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isVideo ? Icons.videocam : Icons.call,
          color: ColorConstants.primaryBlue,
        ),
        onPressed: () {
          // Future: Make call directly from here
        },
      ),
      onTap: () {
        Get.to(() => ChatDetailScreen(user: user));
      },
    );
  }
}
