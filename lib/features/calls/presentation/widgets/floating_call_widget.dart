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
    final screenSize = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final width = _callService.isVideoCall ? 156.0 : 220.0;
    final height = _callService.isVideoCall ? 208.0 : 96.0;

    return Positioned(
      left: _position.dx.clamp(8.0, screenSize.width - width - 8.0),
      top: _position.dy.clamp(safeTop + 8.0, screenSize.height - height - 8.0),
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _controller.openCallScreen,
          onPanUpdate: (details) {
            setState(() {
              _position += details.delta;
              _position = Offset(
                _position.dx.clamp(8.0, screenSize.width - width - 8.0),
                _position.dy.clamp(
                  safeTop + 8.0,
                  screenSize.height - height - 8.0,
                ),
              );
            });
            widget.onPositionChanged(_position);
          },
          child: Container(
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
                      right: 8,
                      bottom: 8,
                      child: _HangupButton(onPressed: _callService.endCall),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

  Widget _buildVoicePreview() {
    final caller = _callService.remoteUserId ?? 'Active call';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 52, 10),
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

class _HangupButton extends StatelessWidget {
  const _HangupButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.call_end, color: Colors.white, size: 20),
      ),
    );
  }
}
