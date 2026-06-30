import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../services/remote_control_service.dart';
import '../controllers/call_controller.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const double _screenShareBottomInset = 128;

  final CallController controller = Get.find<CallController>();
  final RemoteControlService remoteControlService =
      Get.find<RemoteControlService>();
  Offset? _remoteControlPanStart;
  Offset? _remoteControlPanLast;
  DateTime? _remoteControlPanStartedAt;

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
        body: Obx(() {
          final isVideoCall = controller.callService.isVideoCall;
          final remoteScreenSharing =
              remoteControlService.remoteScreenSharing.value;
          final remoteControlActive =
              isVideoCall &&
              remoteControlService.hasControl.value &&
              remoteScreenSharing &&
              controller.callService.remoteRenderers.isNotEmpty;

          return controller.isInPipMode.value
              ? _buildPipBody()
              : SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: remoteScreenSharing
                            ? _screenShareBottomInset
                            : 0,
                        child: isVideoCall
                            ? _buildRemoteVideoStage()
                            : _buildVoiceCallStage(),
                      ),
                      if (remoteControlActive)
                        _buildRemoteControlTouchLayer(
                          bottomInset: _screenShareBottomInset,
                        ),
                      if (remoteControlActive) _buildRemoteControlActions(),
                      if (isVideoCall &&
                          !remoteControlActive &&
                          (!controller.callService.isGroupCall ||
                              controller
                                  .callService
                                  .remoteRenderers
                                  .isNotEmpty))
                        _buildLocalPreview(),
                      _buildTopBar(),
                      _buildBottomControls(),
                    ],
                  ),
                );
        }),
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

  Widget _buildVoiceCallStage() {
    return Obx(() {
      final isCalling = controller.callService.isCalling.value;
      final isMuted = !controller.callService.isAudioEnabled.value;
      final label = controller.callService.remoteUserId ?? 'Active call';

      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF151515), Color(0xFF050505)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: Colors.white10,
                  child: Icon(
                    isMuted ? Icons.mic_off : Icons.call,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isCalling ? 'Calling...' : controller.callDuration.value,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
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
      final isGroupCall = controller.callService.isGroupCall;
      final hasLocal = controller.callService.hasLocalStream.value;
      final isLocalVideoEnabled = controller.callService.isVideoEnabled.value;
      final isRemoteScreenShare =
          remoteControlService.remoteScreenSharing.value;
      final remoteObjectFit = isRemoteScreenShare
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;

      if (isGroupCall) {
        final tiles = <_VideoTile>[
          if (renderers.isEmpty && hasLocal)
            _VideoTile(
              renderer: controller.callService.localRenderer.value,
              label: 'You',
              mirror: true,
              isVideoEnabled: isLocalVideoEnabled,
            ),
          ...renderers.map(
            (renderer) => _VideoTile(
              renderer: renderer,
              label: null,
              isVideoEnabled: true,
            ),
          ),
        ];

        if (tiles.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return _buildParticipantGrid(tiles);
      }

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
        return _buildRendererView(renderers[0], objectFit: remoteObjectFit);
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
            child: RTCVideoView(renderers[index], objectFit: remoteObjectFit),
          );
        },
      );
    });
  }

  Widget _buildParticipantGrid(List<_VideoTile> tiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final topPadding = 76.0;
        final bottomPadding = 112.0;
        final usableHeight = (height - topPadding - bottomPadding)
            .clamp(220.0, height)
            .toDouble();

        if (tiles.length == 1) {
          return Padding(
            padding: EdgeInsets.fromLTRB(8, topPadding, 8, bottomPadding),
            child: _buildParticipantTile(tiles.first),
          );
        }

        if (tiles.length == 2) {
          final tileHeight = (usableHeight - gap) / 2;
          return Padding(
            padding: EdgeInsets.fromLTRB(8, topPadding, 8, bottomPadding),
            child: Column(
              children: [
                SizedBox(
                  height: tileHeight,
                  child: _buildParticipantTile(tiles[0]),
                ),
                const SizedBox(height: gap),
                SizedBox(
                  height: tileHeight,
                  child: _buildParticipantTile(tiles[1]),
                ),
              ],
            ),
          );
        }

        if (tiles.length == 3) {
          final topTileHeight = usableHeight * 0.58;
          final bottomTileHeight = usableHeight - topTileHeight - gap;
          final bottomTileWidth = (width - 16 - gap) / 2;
          return Padding(
            padding: EdgeInsets.fromLTRB(8, topPadding, 8, bottomPadding),
            child: Column(
              children: [
                SizedBox(
                  height: topTileHeight,
                  width: double.infinity,
                  child: _buildParticipantTile(tiles[0]),
                ),
                const SizedBox(height: gap),
                Row(
                  children: [
                    SizedBox(
                      height: bottomTileHeight,
                      width: bottomTileWidth,
                      child: _buildParticipantTile(tiles[1]),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(
                      height: bottomTileHeight,
                      width: bottomTileWidth,
                      child: _buildParticipantTile(tiles[2]),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(8, topPadding, 8, bottomPadding),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) => _buildParticipantTile(tiles[index]),
        );
      },
    );
  }

  Widget _buildParticipantTile(_VideoTile tile) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tile.isVideoEnabled)
              RTCVideoView(
                tile.renderer,
                mirror: tile.mirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Icon(
                    Icons.videocam_off,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            if (tile.label != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      tile.label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _buildRendererView(
    RTCVideoRenderer renderer, {
    bool mirror = false,
    RTCVideoViewObjectFit objectFit =
        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  }) {
    return ColoredBox(
      color: Colors.black,
      child: RTCVideoView(renderer, mirror: mirror, objectFit: objectFit),
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
              Obx(() {
                final isInCall = controller.callService.isInCall.value;
                final canUsePip =
                    controller.callService.isVideoCall &&
                    isInCall &&
                    remoteControlService.grantedControllerId.value.isEmpty;
                return canUsePip
                    ? IconButton(
                        icon: const Icon(
                          Icons.picture_in_picture_alt,
                          color: Colors.white,
                        ),
                        onPressed: controller.enterPip,
                      )
                    : const SizedBox(width: 48);
              }),
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
          controller.callService.isVideoCall
              ? IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                  onPressed: _switchCamera,
                )
              : const SizedBox(width: 48),
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
          Obx(() {
            final isInCall = controller.callService.isInCall.value;
            final showAudioOutput = isInCall;
            return showAudioOutput
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
                : const SizedBox.shrink();
          }),
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
          if (controller.callService.isVideoCall)
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
          if (controller.callService.isVideoCall)
            Obx(
              () => _buildControlButton(
                icon: Icons.screen_share,
                isActive: controller.callService.isScreenSharing.value,
                onPressed: controller.callService.toggleScreenShare,
                onLongPress: controller.callService.toggleFullScreenShare,
              ),
            ),
          if (controller.callService.isVideoCall)
            Obx(() {
              final showRemoteControl =
                  remoteControlService.remoteScreenSharing.value ||
                  remoteControlService.hasControl.value;
              if (!showRemoteControl) return const SizedBox.shrink();

              return _buildControlButton(
                icon: Icons.touch_app,
                isActive: remoteControlService.hasControl.value,
                onPressed: _handleRemoteControlButton,
                onLongPress: remoteControlService.hasControl.value
                    ? remoteControlService.stopControlling
                    : null,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRemoteControlTouchLayer({required double bottomInset}) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Offset normalize(Offset position) {
            final width = constraints.maxWidth <= 0
                ? 1.0
                : constraints.maxWidth;
            final height = constraints.maxHeight <= 0
                ? 1.0
                : constraints.maxHeight;
            final x = (position.dx / width).clamp(0.0, 1.0);
            final y = (position.dy / height).clamp(0.0, 1.0);
            return Offset(x, y);
          }

          void resetPan() {
            _remoteControlPanStart = null;
            _remoteControlPanLast = null;
            _remoteControlPanStartedAt = null;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final point = normalize(details.localPosition);
              remoteControlService.sendTap(
                normalizedX: point.dx,
                normalizedY: point.dy,
              );
            },
            onPanStart: (details) {
              final point = normalize(details.localPosition);
              _remoteControlPanStart = point;
              _remoteControlPanLast = point;
              _remoteControlPanStartedAt = DateTime.now();
            },
            onPanEnd: (_) {
              final start = _remoteControlPanStart;
              final end = _remoteControlPanLast;
              if (start != null &&
                  end != null &&
                  (end - start).distance > 0.02) {
                final elapsedMs = DateTime.now()
                    .difference(_remoteControlPanStartedAt ?? DateTime.now())
                    .inMilliseconds;
                remoteControlService.sendSwipe(
                  startX: start.dx,
                  startY: start.dy,
                  endX: end.dx,
                  endY: end.dy,
                  durationMs: elapsedMs.clamp(90, 450).toInt(),
                );
              }
              resetPan();
            },
            onPanCancel: resetPan,
            onPanUpdate: (details) {
              if (_remoteControlPanStart == null) return;
              _remoteControlPanLast = normalize(details.localPosition);
            },
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  Widget _buildRemoteControlActions() {
    return Positioned(
      top: 92,
      right: 18,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRemoteActionButton(
              icon: Icons.arrow_back,
              onPressed: remoteControlService.sendBack,
            ),
            const SizedBox(height: 10),
            _buildRemoteActionButton(
              icon: Icons.home,
              onPressed: remoteControlService.sendHome,
            ),
            const SizedBox(height: 10),
            _buildRemoteActionButton(
              icon: Icons.apps,
              onPressed: remoteControlService.sendRecents,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _handleRemoteControlButton() {
    if (remoteControlService.hasControl.value) {
      remoteControlService.stopControlling();
      return;
    }
    remoteControlService.requestControl();
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
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
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

class _VideoTile {
  const _VideoTile({
    required this.renderer,
    required this.isVideoEnabled,
    this.label,
    this.mirror = false,
  });

  final RTCVideoRenderer renderer;
  final bool isVideoEnabled;
  final String? label;
  final bool mirror;
}
