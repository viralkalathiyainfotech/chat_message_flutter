import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../controllers/call_controller.dart';

class CallScreen extends GetView<CallController> {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button during call
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          controller.callService.endCall();
          Get.back();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Remote Video (Full Screen)
              Positioned.fill(
                child: Obx(() {
                  final hasRemote = controller.callService.hasRemoteStream.value;
                  return hasRemote
                      ? RTCVideoView(
                          controller.callService.remoteRenderer.value,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 20),
                              Text(
                                'Connecting...',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                            ],
                          ),
                        );
                }),
              ),

              // Local Video (Small overlay in corner)
              Positioned(
                right: 20,
                bottom: 120, // Above controls
                width: 120,
                height: 160,
                child: Obx(() {
                  final hasLocal = controller.callService.hasLocalStream.value;
                  return hasLocal && controller.callService.isVideoEnabled.value
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: RTCVideoView(
                              controller.callService.localRenderer.value,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                }),
              ),

              // Top Bar
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Obx(() {
                        return Text(
                          controller.callService.isCalling.value ? 'Calling...' : '00:00', // Basic timer placeholder
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                      onPressed: () {
                        // Implement switch camera
                        if (controller.callService.localStream != null) {
                          Helper.switchCamera(controller.callService.localStream!.getVideoTracks()[0]);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Bottom Control Bar
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Audio
                    Obx(() => _buildControlButton(
                          icon: controller.callService.isAudioEnabled.value
                              ? Icons.mic
                              : Icons.mic_off,
                          isActive: !controller.callService.isAudioEnabled.value,
                          onPressed: controller.callService.toggleAudio,
                        )),
                    // End Call
                    FloatingActionButton(
                      heroTag: 'end_call_btn',
                      backgroundColor: Colors.red,
                      onPressed: () {
                        controller.callService.endCall();
                        Get.back();
                      },
                      child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                    // Toggle Video
                    Obx(() => _buildControlButton(
                          icon: controller.callService.isVideoEnabled.value
                              ? Icons.videocam
                              : Icons.videocam_off,
                          isActive: !controller.callService.isVideoEnabled.value,
                          onPressed: controller.callService.toggleVideo,
                        )),
                    // Screen Share
                    Obx(() => _buildControlButton(
                          icon: Icons.screen_share,
                          isActive: controller.callService.isScreenSharing.value,
                          onPressed: controller.callService.toggleScreenShare,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
