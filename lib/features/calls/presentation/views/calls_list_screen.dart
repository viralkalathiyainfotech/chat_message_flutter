import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/calls_controller.dart';
import '../controllers/call_controller.dart';

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
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: Obx(() {
        if (controller.calls.isEmpty) {
          return const Center(child: Text('No call history.'));
        }

        // Group calls by dateGroup
        final Map<String, List<CallRecord>> groupedCalls = {};
        for (var record in controller.calls) {
          groupedCalls.putIfAbsent(record.dateGroup, () => []).add(record);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: groupedCalls.length,
          itemBuilder: (context, index) {
            final dateGroup = groupedCalls.keys.elementAt(index);
            final groupRecords = groupedCalls[dateGroup]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
                  child: Text(
                    dateGroup,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: List.generate(groupRecords.length, (itemIndex) {
                      final record = groupRecords[itemIndex];
                      final isLast = itemIndex == groupRecords.length - 1;

                      return Column(
                        children: [
                          _buildCallItem(record, context),
                          if (!isLast)
                            const Divider(height: 1, indent: 68, color: Colors.white10),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: ColorConstants.primaryBlue,
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
    );
  }

  Widget _buildCallItem(CallRecord record, BuildContext context) {
    final user = record.user;

    IconData statusIcon = Icons.call_made;
    Color statusColor = Colors.redAccent;

    if (record.callType == 'missed') {
      statusIcon = Icons.phone_missed;
      statusColor = Colors.redAccent;
    } else if (record.callType == 'incoming') {
      statusIcon = Icons.call_received;
      statusColor = Colors.greenAccent;
    } else {
      statusIcon = Icons.call_made;
      statusColor = Colors.redAccent;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade800,
        backgroundImage: CachedNetworkImageProvider(record.avatarUrl),
      ),
      title: Text(
        record.title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                record.subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      trailing: Text(
        record.timeString,
        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      onTap: () {
        // Call the API properly as requested by the user
        final callController = Get.find<CallController>();
        callController.startCall(user.id, video: false, isGroup: user.isGroup == true);
      },
    );
  }
}
