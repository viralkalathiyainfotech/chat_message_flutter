import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/chat_detail_controller.dart';
import 'gallery_selection_preview_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  final ChatDetailController chatController;

  const CameraCaptureScreen({super.key, required this.chatController});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(_cameras![_selectedCameraIndex], ResolutionPreset.high);
        await _cameraController!.initialize();
        if (mounted) {
          setState(() { _isInitialized = true; });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization failed, using simulated fallback: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _cameraController?.dispose();
    _cameraController = CameraController(_cameras![_selectedCameraIndex], ResolutionPreset.high);
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _takePicture() async {
    String capturedPath = 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=1000&auto=format&fit=crop';
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xfile = await _cameraController!.takePicture();
        capturedPath = xfile.path;
      } catch (e) {
        debugPrint('Capture failed, using simulated fallback: $e');
      }
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GallerySelectionPreviewScreen(
            selectedFilePaths: [capturedPath],
            chatController: widget.chatController,
          ),
        ),
      );
    }
  }

  Future<void> _openGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GallerySelectionPreviewScreen(
            selectedFilePaths: images.map((e) => e.path).toList(),
            chatController: widget.chatController,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Feed or Simulated Fallback
            Positioned.fill(
              child: (_isInitialized && _cameraController != null)
                  ? CameraPreview(_cameraController!)
                  : Image.network(
                      'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=1000&auto=format&fit=crop', // Beautiful red rose image matching design
                      fit: BoxFit.cover,
                    ),
            ),
            // Focus Brackets Overlay
            Center(
              child: SizedBox(
                width: 280,
                height: 380,
                child: Stack(
                  children: [
                    // Top Left Bracket
                    Positioned(top: 0, left: 0, child: _buildCornerBracket(top: true, left: true)),
                    // Top Right Bracket
                    Positioned(top: 0, right: 0, child: _buildCornerBracket(top: true, left: false)),
                    // Bottom Left Bracket
                    Positioned(bottom: 0, left: 0, child: _buildCornerBracket(top: false, left: true)),
                    // Bottom Right Bracket
                    Positioned(bottom: 0, right: 0, child: _buildCornerBracket(top: false, left: false)),
                    // Center Focus Square
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top Bar
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    const SizedBox(width: 4),
                    const Text('Camera', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            // Bottom Action Bar
            Positioned(
              bottom: 32,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Gallery Thumbnail
                  GestureDetector(
                    onTap: _openGallery,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        image: const DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=150&auto=format&fit=crop'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  // Center Circular Shutter Button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right Flip Camera Button
                  GestureDetector(
                    onTap: _flipCamera,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cameraswitch, color: Colors.white, size: 28),
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

  Widget _buildCornerBracket({required bool top, required bool left}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
