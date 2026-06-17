import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../services/call_service.dart';
import '../../../../services/call_notification_service.dart';
import '../../../../services/call_overlay_service.dart';
import '../../../../services/call_pip_service.dart';
import '../views/call_screen.dart';
import 'dart:async';

class CallController extends GetxController {
  final CallService callService = Get.find<CallService>();
  final CallOverlayService _overlayService = Get.find<CallOverlayService>();
  final CallPipService _pipService = Get.find<CallPipService>();
  final CallNotificationService _notificationService =
      Get.find<CallNotificationService>();

  final RxString callDuration = '00:00'.obs;
  final RxBool isFullCallScreenVisible = false.obs;
  final RxBool isMinimizingToOverlay = false.obs;
  RxBool get isInPipMode => _pipService.isInPipMode;
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
        _pipService.setCallActive(
          callService.isVideoCall,
          audioEnabled: callService.isAudioEnabled.value,
          videoEnabled: callService.isVideoEnabled.value,
        );
        _showOrUpdateNotification();
        openCallScreen();
      } else {
        _stopTimer();
        _overlayService.hideOverlay();
        _notificationService.stopOngoingCall();
        _pipService.setCallActive(false);
        // If we are on the call screen, go back
        if (isFullCallScreenVisible.value ||
            Get.currentRoute == '/CallScreen') {
          isFullCallScreenVisible.value = false;
          Get.back();
        }
      }
    });

    everAll(
      [
        callService.isAudioEnabled,
        callService.isVideoEnabled,
        callService.isScreenSharing,
      ],
      (_) {
        if (!callService.isInCall.value) return;
        _pipService.updateCallControls(
          audioEnabled: callService.isAudioEnabled.value,
          videoEnabled: callService.isVideoEnabled.value,
        );
        _showOrUpdateNotification();
      },
    );
  }

  void startCall(
    String userId, {
    bool video = true,
    bool isGroup = false,
    List<String>? participants,
  }) async {
    final didStart = await callService.makeCall(
      userId,
      video: video,
      isGroup: isGroup,
      participants: participants,
    );
    if (didStart) {
      openCallScreen();
    }
  }

  void openCallScreen() {
    _overlayService.hideOverlay();
    if (isFullCallScreenVisible.value || Get.currentRoute == '/CallScreen') {
      return;
    }
    isFullCallScreenVisible.value = true;
    Get.to(() => const CallScreen())?.whenComplete(() {
      isFullCallScreenVisible.value = false;
    });
  }

  void hideFullCallScreenForOverlay() {
    if (!callService.isInCall.value && !callService.isCalling.value) return;
    isMinimizingToOverlay.value = true;
    if (isFullCallScreenVisible.value || Get.currentRoute == '/CallScreen') {
      Get.back();
    } else {
      showOverlayAfterCallScreenClosed();
    }
  }

  void showOverlayAfterCallScreenClosed() {
    isFullCallScreenVisible.value = false;
    isMinimizingToOverlay.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isFullCallScreenVisible.value &&
          (callService.isInCall.value || callService.isCalling.value)) {
        _overlayService.showOverlay();
      }
    });
  }

  Future<void> enterPip() async {
    if (callService.isInCall.value && callService.isVideoCall) {
      final didEnter = await _pipService.enterPip();
      if (!didEnter) {
        Get.snackbar(
          'PiP unavailable',
          'Your device or current screen did not allow picture-in-picture.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void _showOrUpdateNotification() {
    if (!callService.isInCall.value) return;
    final typeLabel = callService.isVideoCall ? 'Video call' : 'Voice call';
    final remoteName = callService.remoteUserId ?? 'Active call';
    _notificationService.showOngoingCall(
      title: typeLabel,
      body: '$remoteName • ongoing',
      isVideo: callService.isVideoCall,
      audioEnabled: callService.isAudioEnabled.value,
      videoEnabled: callService.isVideoEnabled.value,
      isScreenSharing: callService.isScreenSharing.value,
    );
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
