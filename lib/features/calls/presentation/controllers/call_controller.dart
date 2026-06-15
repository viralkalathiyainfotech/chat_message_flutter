import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
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

  final floating = Floating();

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
        if (callService.isVideoCall) {
          floating.enable(OnLeavePiP(aspectRatio: Rational.vertical()));
        }
        Get.to(() => const CallScreen());
      } else {
        _stopTimer();
        hideInAppOverlay();
        floating.cancelOnLeavePiP();
        // If we are on the call screen, go back
        if (Get.currentRoute == '/CallScreen' || Get.isOverlaysOpen) {
          Get.back();
        }
      }
    });
  }

  OverlayEntry? _overlayEntry;

  void showInAppOverlay() {
    if (!callService.isVideoCall) {
       Get.snackbar("Audio Call", "Overlay disabled for audio calls.");
       return;
    }
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        right: 20,
        bottom: 120,
        width: 120,
        height: 160,
        child: GestureDetector(
          onTap: () {
            hideInAppOverlay();
            Get.to(() => const CallScreen());
          },
          child: Material(
            color: Colors.black,
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 2), // Bright border for debugging
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Remote Video
                  Positioned.fill(
                    child: Obx(() {
                      final renderers = callService.remoteRenderers.values.toList();
                      if (renderers.isNotEmpty && callService.isVideoCall) {
                        return RTCVideoView(
                          renderers[0],
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        );
                      }
                      return const Center(child: Icon(Icons.call, color: Colors.green, size: 40));
                    }),
                  ),
                  // Local Video
                  Positioned(
                    left: 5,
                    bottom: 5,
                    width: 40,
                    height: 60,
                    child: Obx(() {
                      if (callService.hasLocalStream.value && callService.isVideoEnabled.value) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: RTCVideoView(
                              callService.localRenderer.value,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ),
                  // Hang up button
                  Positioned(
                    top: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: () {
                        hideInAppOverlay();
                        callService.endCall();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    final overlayState = Get.overlayContext != null 
        ? Overlay.of(Get.overlayContext!) 
        : Get.key.currentState?.overlay;
        
    if (overlayState != null) {
      overlayState.insert(_overlayEntry!);
    } else {
      Get.log("ERROR: Overlay State is null!");
      _overlayEntry = null;
    }
  }

  void hideInAppOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void triggerPiP() async {
    final canUsePip = await floating.isPipAvailable;
    if (canUsePip) {
       floating.enable(ImmediatePiP());
    }
  }

  void startCall(String userId, {bool video = true, bool isGroup = false, List<String>? participants}) async {
    await callService.makeCall(userId, video: video, isGroup: isGroup, participants: participants);
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
