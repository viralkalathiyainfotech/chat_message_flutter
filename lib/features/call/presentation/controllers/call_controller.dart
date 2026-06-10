import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../services/call_service.dart';
import '../views/call_screen.dart';

class CallController extends GetxController {
  final CallService callService = Get.find<CallService>();

  @override
  void onInit() {
    super.onInit();

    // Listen for incoming calls
    ever(callService.isReceivingCall, (bool isReceiving) {
      if (isReceiving && callService.incomingCallData != null) {
        _showIncomingCallOverlay();
      } else {
        if (Get.isDialogOpen ?? false) {
          Get.back(); // Dismiss incoming call dialog if dismissed from backend
        }
      }
    });

    // Listen for accepted/outgoing active calls
    ever(callService.isInCall, (bool isInCall) {
      if (isInCall) {
        Get.to(() => const CallScreen());
      } else {
        // If we are on the call screen, go back
        if (Get.currentRoute == '/CallScreen') {
          Get.back();
        }
      }
    });
  }

  void startCall(String userId, {bool video = true}) async {
    await callService.makeCall(userId, video: video);
    Get.to(() => const CallScreen());
  }

  void _showIncomingCallOverlay() {
    final callerId = callService.remoteUserId;
    final isVideo = callService.incomingCallData?['type'] == 'video';

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Get.theme.primaryColor.withValues(alpha: 0.2),
              child: Icon(
                isVideo ? Icons.videocam : Icons.phone,
                size: 40,
                color: Get.theme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Incoming ${isVideo ? 'Video' : 'Voice'} Call',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'From: $callerId',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'decline_btn',
                onPressed: () {
                  callService.declineCall();
                  Get.back();
                },
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
              FloatingActionButton(
                heroTag: 'accept_btn',
                onPressed: () {
                  Get.back();
                  callService.acceptCall();
                },
                backgroundColor: Colors.green,
                child: const Icon(Icons.call, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
