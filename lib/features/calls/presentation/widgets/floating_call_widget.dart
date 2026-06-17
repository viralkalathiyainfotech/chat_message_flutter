import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';

import '../../../../services/call_service.dart';
import '../controllers/call_controller.dart';

class FloatingCallWidget extends StatefulWidget {
  const FloatingCallWidget({
    super.key,
    required this.initialPosition,
    required this.onPositionChanged,
  });

  final Offset initialPosition;
  final ValueChanged<Offset> onPositionChanged;

  @override
  State<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<FloatingCallWidget> {
  final CallController _controller = Get.find<CallController>();
  final CallService _callService = Get.find<CallService>();
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = constraints.biggest;
          if (screenSize.width < 64 || screenSize.height < 64) {
            return const SizedBox.shrink();
          }

          final safeTop = MediaQuery.paddingOf(context).top;
          final desiredWidth = _callService.isVideoCall ? 172.0 : 238.0;
          final desiredHeight = _callService.isVideoCall ? 238.0 : 116.0;
          final width = desiredWidth.clamp(56.0, screenSize.width);
          final height = desiredHeight.clamp(56.0, screenSize.height);
          final clampedPosition = _clampPosition(
            _position,
            screenSize: screenSize,
            safeTop: safeTop,
            width: width,
            height: height,
          );

          return Stack(
            children: [
              Positioned(
                left: clampedPosition.dx,
                top: clampedPosition.dy,
                width: width,
                height: height,
                child: Material(
                  color: Colors.transparent,
                  child: _buildOverlayCard(
                    onDragUpdate: (details) {
                      _moveOverlay(
                        details.delta,
                        screenSize: screenSize,
                        safeTop: safeTop,
                        width: width,
                        height: height,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _moveOverlay(
    Offset delta, {
    required Size screenSize,
    required double safeTop,
    required double width,
    required double height,
  }) {
    setState(() {
      _position = _clampPosition(
        _position + delta,
        screenSize: screenSize,
        safeTop: safeTop,
        width: width,
        height: height,
      );
    });
    widget.onPositionChanged(_position);
  }

  Widget _buildOverlayCard({required GestureDragUpdateCallback onDragUpdate}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white30, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Obx(
          () => Stack(
            fit: StackFit.expand,
            children: [
              _callService.isVideoCall
                  ? _buildVideoPreview()
                  : _buildVoicePreview(),
              if (_callService.isVideoCall) _buildLocalPreview(),
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                bottom: 52,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _controller.openCallScreen,
                  onPanUpdate: onDragUpdate,
                ),
              ),
              Positioned(
                left: 8,
                top: 7,
                right: 8,
                child: _OverlayHeader(
                  isVideo: _callService.isVideoCall,
                  duration: _controller.callDuration.value,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: _OverlayControls(
                  isVideoCall: _callService.isVideoCall,
                  isAudioEnabled: _callService.isAudioEnabled.value,
                  isVideoEnabled: _callService.isVideoEnabled.value,
                  onToggleAudio: _callService.toggleAudio,
                  onToggleVideo: _callService.toggleVideo,
                  onHangup: _callService.endCall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _clampPosition(
    Offset position, {
    required Size screenSize,
    required double safeTop,
    required double width,
    required double height,
  }) {
    final minLeft = 8.0;
    final minTop = safeTop + 8.0;
    final maxLeft = (screenSize.width - width - 8.0).clamp(
      minLeft,
      double.infinity,
    );
    final maxTop = (screenSize.height - height - 8.0).clamp(
      minTop,
      double.infinity,
    );

    return Offset(
      position.dx.clamp(minLeft, maxLeft),
      position.dy.clamp(minTop, maxTop),
    );
  }

  Widget _buildVideoPreview() {
    final renderers = _callService.remoteRenderers.values.toList();
    final renderer = renderers.isNotEmpty
        ? renderers.first
        : (_callService.hasLocalStream.value
              ? _callService.localRenderer.value
              : null);

    if (renderer == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Connecting',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return RTCVideoView(
      renderer,
      mirror: renderers.isEmpty,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }

  Widget _buildLocalPreview() {
    final hasRemote = _callService.remoteRenderers.isNotEmpty;
    if (!hasRemote ||
        !_callService.hasLocalStream.value ||
        !_callService.isVideoEnabled.value) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 8,
      bottom: 58,
      width: 46,
      height: 64,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white70, width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: RTCVideoView(
              _callService.localRenderer.value,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoicePreview() {
    final caller = _callService.remoteUserId ?? 'Active call';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 52),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Get.theme.primaryColor.withValues(alpha: 0.22),
            child: Icon(Icons.call, color: Get.theme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caller,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _controller.callDuration.value,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({required this.isVideo, required this.duration});

  final bool isVideo;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.videocam : Icons.call,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              duration,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.drag_indicator, color: Colors.white70, size: 14),
        ],
      ),
    );
  }
}

class _OverlayControls extends StatelessWidget {
  const _OverlayControls({
    required this.isVideoCall,
    required this.isAudioEnabled,
    required this.isVideoEnabled,
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onHangup,
  });

  final bool isVideoCall;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      _OverlayControlButton(
        icon: isAudioEnabled ? Icons.mic : Icons.mic_off,
        isActive: !isAudioEnabled,
        onPressed: onToggleAudio,
      ),
      _OverlayControlButton(
        icon: Icons.call_end,
        color: Colors.red,
        onPressed: onHangup,
      ),
      if (isVideoCall)
        _OverlayControlButton(
          icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
          isActive: !isVideoEnabled,
          onPressed: onToggleVideo,
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: controls,
        ),
      ),
    );
  }
}

class _OverlayControlButton extends StatelessWidget {
  const _OverlayControlButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? (isActive ? Colors.white : Colors.white24);
    final foreground = color != null || !isActive ? Colors.white : Colors.black;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: foreground, size: 20),
        ),
      ),
    );
  }
}
