import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';

import '../controllers/call_controller.dart';

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CallController>();
    final isVideo = controller.callService.incomingCallData?['type'] == 'video';
    final callerName = controller.callService.callDisplayName;
    final callLabel = isVideo ? 'Incoming video call' : 'Incoming voice call';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF09110E),
        body: Stack(
          fit: StackFit.expand,
          children: [
            isVideo
                ? _IncomingVideoBackground(controller: controller)
                : const _IncomingVoiceBackground(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    if (!isVideo) ...[
                      _CallerBadge(isVideo: isVideo),
                      const SizedBox(height: 28),
                    ],
                    Text(
                      callerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      callLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RingingPill(isVideo: isVideo),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CallActionButton(
                          label: 'Decline',
                          icon: Icons.call_end,
                          color: const Color(0xFFE53935),
                          onPressed: controller.declineIncomingCall,
                        ),
                        _CallActionButton(
                          label: 'Answer',
                          icon: isVideo ? Icons.videocam : Icons.call,
                          color: const Color(0xFF18B66A),
                          onPressed: controller.answerIncomingCall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingVideoBackground extends StatelessWidget {
  const _IncomingVideoBackground({required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasLocal = controller.callService.hasLocalStream.value;
      final videoEnabled = controller.callService.isVideoEnabled.value;
      if (hasLocal && videoEnabled) {
        return RTCVideoView(
          controller.callService.localRenderer.value,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      }

      return const ColoredBox(
        color: Color(0xFF09110E),
        child: Center(
          child: Icon(Icons.videocam, color: Colors.white70, size: 64),
        ),
      );
    });
  }
}

class _IncomingVoiceBackground extends StatelessWidget {
  const _IncomingVoiceBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151515), Color(0xFF050505)],
        ),
      ),
    );
  }
}

class _CallerBadge extends StatelessWidget {
  const _CallerBadge({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Icon(
        isVideo ? Icons.videocam : Icons.call,
        color: Colors.white,
        size: 48,
      ),
    );
  }
}

class _RingingPill extends StatelessWidget {
  const _RingingPill({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.videocam_outlined : Icons.phone_in_talk,
              color: const Color(0xFF71E5A6),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isVideo ? 'Ringing on video' : 'Ringing on audio',
              style: const TextStyle(
                color: Color(0xFFDEF7E9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: FloatingActionButton(
              heroTag: label,
              elevation: 0,
              backgroundColor: color,
              onPressed: onPressed,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
