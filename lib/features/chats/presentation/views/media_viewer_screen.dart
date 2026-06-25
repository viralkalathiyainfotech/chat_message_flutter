import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/database/realm_models.dart';
import '../controllers/chat_detail_controller.dart';
import 'forward_messages_screen.dart';

class MediaViewerScreen extends StatefulWidget {
  final MessageRealm message;
  final bool isMe;
  final ChatDetailController chatController;
  final bool isVideo;

  const MediaViewerScreen({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatController,
    required this.isVideo,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  bool _isPlaying = false;
  double _progress = 0.15; // Starting around 00:10 of 01:04 matching design
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _isPlaying = true;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          _progress += 0.005;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
            _timer?.cancel();
          }
        });
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWebUrl = (widget.message.content?.content?.startsWith('http') ?? false) || (widget.message.content?.fileUrl?.startsWith('http') ?? false);
    final String path = widget.message.content?.fileUrl ?? widget.message.content?.content ?? '';

    final int totalSeconds = 64; // 01:04
    final int elapsedSeconds = (_progress * totalSeconds).round();
    final String elapsedStr = '00:${elapsedSeconds.toString().padLeft(2, '0')}';
    final String totalStr = '01:04';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Media View
            Positioned.fill(
              child: Center(
                child: widget.isVideo
                    ? Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library, size: 72, color: Theme.of(context).primaryColor),
                            const SizedBox(height: 16),
                            Text(
                              path.split('/').last,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Video File Player',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : (isWebUrl
                        ? Image.network(
                            path,
                            fit: BoxFit.contain,
                            errorBuilder: (context, err, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 80),
                          )
                        : Image.file(
                            File(path),
                            fit: BoxFit.contain,
                            errorBuilder: (context, err, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 80),
                          )),
              ),
            ),
            // Video Overlays
            if (widget.isVideo) ...[
              // Center Play/Pause Button Overlay
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Scrubber Bar
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _progress,
                        onChanged: (val) {
                          setState(() { _progress = val; });
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(elapsedStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(totalStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // Top Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.reply, color: Colors.white, size: 24),
                        onPressed: () {
                          widget.chatController.selectedMessageIds.add(widget.message.id);
                          Get.to(() => ForwardMessagesScreen(
                            messages: [widget.message],
                            controller: widget.chatController,
                          ));
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white, size: 24),
                        onPressed: () {
                          widget.chatController.downloadAttachment(widget.message.id);
                          Get.snackbar('Download', 'Media saved to gallery successfully.', colorText: Colors.white);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
