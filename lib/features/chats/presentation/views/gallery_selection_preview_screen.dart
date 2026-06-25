import 'package:flutter/material.dart';
import 'dart:io';
import '../../../../constants/color_constants.dart';
import '../controllers/chat_detail_controller.dart';

class GallerySelectionPreviewScreen extends StatefulWidget {
  final List<String> selectedFilePaths;
  final ChatDetailController chatController;

  const GallerySelectionPreviewScreen({
    super.key,
    required this.selectedFilePaths,
    required this.chatController,
  });

  @override
  State<GallerySelectionPreviewScreen> createState() => _GallerySelectionPreviewScreenState();
}

class _GallerySelectionPreviewScreenState extends State<GallerySelectionPreviewScreen> {
  int _currentIndex = 0;
  final TextEditingController _captionController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') || lower.contains('video');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedFilePaths.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    }

    final currentPath = widget.selectedFilePaths[_currentIndex];
    final bool isCurrentVideo = _isVideo(currentPath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Close Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            // Main Large Preview
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: isCurrentVideo
                          ? Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_library, size: 64, color: Theme.of(context).primaryColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    currentPath.split('/').last,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : (currentPath.startsWith('http')
                              ? Image.network(currentPath, fit: BoxFit.cover)
                              : Image.file(File(currentPath), fit: BoxFit.cover, errorBuilder: (context, err, stack) => const Icon(Icons.broken_image, color: Colors.white, size: 60))),
                    ),
                  ),
                  if (isCurrentVideo)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Thumbnail Preview Row
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                itemCount: widget.selectedFilePaths.length,
                itemBuilder: (context, index) {
                  final path = widget.selectedFilePaths[index];
                  final isSelected = index == _currentIndex;
                  final isVideoItem = _isVideo(path);

                  return GestureDetector(
                    onTap: () {
                      setState(() { _currentIndex = index; });
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            isVideoItem
                                ? Container(
                                    color: Colors.grey.shade800,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.videocam, color: Colors.white, size: 24),
                                  )
                                : (path.startsWith('http')
                                    ? Image.network(path, fit: BoxFit.cover)
                                    : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (context, err, stack) => Container(color: Colors.grey.shade800, child: const Icon(Icons.image, color: Colors.white, size: 20)))),
                            if (isVideoItem) ...[
                              Container(
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Row(
                                  children: [
                                    const Icon(Icons.videocam, color: Colors.white, size: 12),
                                    const SizedBox(width: 2),
                                    const Text('10:30', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: ColorConstants.inputBackground,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _captionController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const Icon(Icons.attach_file, color: Colors.grey, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isSending
                        ? null
                        : () async {
                            setState(() { _isSending = true; });
                            for (final path in widget.selectedFilePaths) {
                              final file = File(path);
                              if (await file.exists()) {
                                await widget.chatController.sendAttachment(
                                  path: path,
                                  fileName: path.split('/').last,
                                  sizeBytes: await file.length(),
                                );
                              } else {
                                // Simulate for mock network paths
                                await widget.chatController.sendAttachment(
                                  path: path,
                                  fileName: 'media_file.jpg',
                                  sizeBytes: 102400,
                                );
                              }
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ColorConstants.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(14.0),
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
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
