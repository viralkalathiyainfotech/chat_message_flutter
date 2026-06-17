import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../controllers/call_controller.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallController controller = Get.find<CallController>();

  @override
  void initState() {
    super.initState();
    controller.isFullCallScreenVisible.value = true;
  }

  @override
  void dispose() {
    controller.isFullCallScreenVisible.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop &&
            (controller.isMinimizingToOverlay.value ||
                controller.callService.isInCall.value ||
                controller.callService.isCalling.value)) {
          controller.showOverlayAfterCallScreenClosed();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(
          () => controller.isInPipMode.value
              ? _buildPipBody()
              : SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildRemoteVideoStage()),
                      _buildLocalPreview(),
                      _buildTopBar(),
                      _buildBottomControls(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPipBody() {
    return Obx(() {
      final hasRemote = controller.callService.remoteRenderers.isNotEmpty;
      final hasLocal = controller.callService.hasLocalStream.value;
      final isVideoEnabled = controller.callService.isVideoEnabled.value;

      return ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPipVideoStage(),
            if (hasRemote && hasLocal && isVideoEnabled)
              _buildPipLocalPreview(),
            Positioned(top: 8, left: 8, right: 8, child: _buildPipStatus()),
          ],
        ),
      );
    });
  }

  Widget _buildPipVideoStage() {
    final remoteRenderers = controller.callService.remoteRenderers.values;
    if (remoteRenderers.isNotEmpty) {
      return _buildRendererView(remoteRenderers.first);
    }

    final hasLocal = controller.callService.hasLocalStream.value;
    final isVideoEnabled = controller.callService.isVideoEnabled.value;
    if (hasLocal && isVideoEnabled) {
      return _buildRendererView(
        controller.callService.localRenderer.value,
        mirror: true,
      );
    }

    return const Center(
      child: Icon(Icons.videocam, color: Colors.white, size: 26),
    );
  }

  Widget _buildPipLocalPreview() {
    return Positioned(
      right: 8,
      bottom: 8,
      width: 46,
      height: 66,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white70, width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: RTCVideoView(
            controller.callService.localRenderer.value,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }

  Widget _buildPipStatus() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.callService.isVideoCall ? Icons.videocam : Icons.call,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                controller.callService.isCalling.value
                    ? 'Calling'
                    : controller.callDuration.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideoStage({bool showConnectingLabel = true}) {
    return Obx(() {
      final renderers = controller.callService.remoteRenderers.values.toList();
      if (renderers.isEmpty) {
        return Center(
          child: showConnectingLabel
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'Connecting...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        );
      }

      if (renderers.length == 1) {
        return _buildRendererView(renderers[0]);
      }

      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: renderers.length > 2 ? 2 : 1,
          childAspectRatio: renderers.length > 2 ? 1.0 : 0.8,
        ),
        itemCount: renderers.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: RTCVideoView(
              renderers[index],
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          );
        },
      );
    });
  }

  Widget _buildLocalPreview() {
    return Positioned(
      right: 20,
      bottom: 120,
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
    );
  }

  Widget _buildRendererView(RTCVideoRenderer renderer, {bool mirror = false}) {
    return ColoredBox(
      color: Colors.black,
      child: RTCVideoView(
        renderer,
        mirror: mirror,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                onPressed: controller.hideFullCallScreenForOverlay,
              ),
              Obx(
                () =>
                    controller.callService.isVideoCall &&
                        controller.callService.isInCall.value
                    ? IconButton(
                        icon: const Icon(
                          Icons.picture_in_picture_alt,
                          color: Colors.white,
                        ),
                        onPressed: controller.enterPip,
                      )
                    : const SizedBox(width: 48),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Obx(() {
              return Text(
                controller.callService.isCalling.value
                    ? 'Calling...'
                    : controller.callDuration.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Obx(
            () => _buildControlButton(
              icon: controller.callService.isAudioEnabled.value
                  ? Icons.mic
                  : Icons.mic_off,
              isActive: !controller.callService.isAudioEnabled.value,
              onPressed: controller.callService.toggleAudio,
            ),
          ),
          // const SizedBox(width: 14),
          // _buildControlButton(
          //   icon: Icons.chat_bubble_outline,
          //   isActive: false,
          //   onPressed: controller.hideFullCallScreenForOverlay,
          // ),
          Obx(
            () =>
                controller.callService.isVideoCall &&
                    controller.callService.isInCall.value
                ? Row(
                    children: [
                      // const SizedBox(width: 14),
                      _buildControlButton(
                        icon: _selectedAudioOutputIcon(),
                        isActive:
                            controller
                                .callService
                                .selectedAudioOutputId
                                .value !=
                            'speaker',
                        onPressed: _showAudioOutputSheet,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          // const SizedBox(width: 14),
          FloatingActionButton(
            heroTag: 'end_call_btn',
            backgroundColor: Colors.red,
            onPressed: () {
              controller.callService.endCall();
              Get.back();
            },
            child: const Icon(Icons.call_end, color: Colors.white, size: 30),
          ),
          // const SizedBox(width: 14),
          Obx(
            () => _buildControlButton(
              icon: controller.callService.isVideoEnabled.value
                  ? Icons.videocam
                  : Icons.videocam_off,
              isActive: !controller.callService.isVideoEnabled.value,
              onPressed: controller.callService.toggleVideo,
            ),
          ),
          // const SizedBox(width: 14),
          Obx(
            () => _buildControlButton(
              icon: Icons.screen_share,
              isActive: controller.callService.isScreenSharing.value,
              onPressed: controller.callService.toggleScreenShare,
            ),
          ),
        ],
      ),
    );
  }

  IconData _selectedAudioOutputIcon() {
    final selectedId = controller.callService.selectedAudioOutputId.value;
    final selectedOutput = controller.callService.audioOutputs.firstWhereOrNull(
      (output) => output.id == selectedId,
    );
    return selectedOutput?.icon ?? Icons.volume_up;
  }

  Future<void> _showAudioOutputSheet() async {
    await controller.callService.refreshAudioOutputs();
    if (!mounted) return;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF151515),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Obx(() {
            final outputs = controller.callService.audioOutputs;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio output',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...outputs.map((output) {
                  final isSelected =
                      output.id ==
                      controller.callService.selectedAudioOutputId.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(output.icon, color: Colors.white),
                    title: Text(
                      output.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () async {
                      await controller.callService.selectAudioOutput(output.id);
                      if (Get.isBottomSheetOpen ?? false) {
                        Get.back();
                      }
                    },
                  );
                }),
              ],
            );
          }),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  void _switchCamera() {
    if (controller.callService.localStream == null) return;
    try {
      final videoTracks = controller.callService.localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        Helper.switchCamera(videoTracks[0]);
      }
    } catch (e) {
      Get.log('Error switching camera: $e');
    }
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
