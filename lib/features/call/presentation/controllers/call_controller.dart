import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../services/call_service.dart';
import '../views/call_screen.dart';
import 'dart:async';

class CallController extends GetxController {
  final CallService callService = Get.find<CallService>();

  final RxString callDuration = '00:00'.obs;
  Timer? _callTimer;
  int _seconds = 0;

  void _startTimer() {
    _seconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
      final secs = (_seconds % 60).toString().padLeft(2, '0');
      callDuration.value = '$minutes:$secs';
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
    callDuration.value = '00:00';
  }

  @override
  void onClose() {
    _stopTimer();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();

    // Listen for incoming calls
    ever(callService.isReceivingCall, (bool isReceiving) {
      if (isReceiving && callService.incomingCallData != null) {
        // Force close any existing dialogs to ensure the incoming call is visible
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        Future.microtask(() => _showIncomingCallOverlay());
      } else {
        if (Get.isDialogOpen ?? false) {
          Get.back(); // Dismiss incoming call dialog if dismissed from backend
        }
      }
    });

    // Listen for accepted/outgoing active calls
    ever(callService.isInCall, (bool isInCall) {
      if (isInCall) {
        _startTimer();
        Get.to(() => const CallScreen());
      } else {
        _stopTimer();
        // If we are on the call screen, go back
        if (Get.currentRoute == '/CallScreen' || Get.isOverlaysOpen) {
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
