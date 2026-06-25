import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ChatCameraScreen extends StatefulWidget {
  const ChatCameraScreen({super.key});

  @override
  State<ChatCameraScreen> createState() => _ChatCameraScreenState();
}

class _ChatCameraScreenState extends State<ChatCameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _cameraIndex = 0;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadCameras());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(controller.dispose());
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initializeCamera(_cameraIndex));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Camera',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildCameraBody()),
          _CameraControls(
            isCapturing: _isCapturing,
            onPickGallery: _pickFromGallery,
            onCapture: _capturePhoto,
            onSwitchCamera: _switchCamera,
            canSwitchCamera: _cameras.length > 1,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraBody() {
    final controller = _cameraController;

    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera is not ready.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        Container(color: Colors.black.withValues(alpha: 0.08)),
        const Center(child: _FocusFrame()),
      ],
    );
  }

  Future<void> _loadCameras() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameras = [];
          _isInitializing = false;
          _errorMessage = 'No camera found on this device.';
        });
        return;
      }

      final backCameraIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      _cameras = cameras;
      _cameraIndex = backCameraIndex == -1 ? 0 : backCameraIndex;
      await _initializeCamera(_cameraIndex);
    } on CameraException catch (error) {
      setState(() {
        _isInitializing = false;
        _errorMessage = _cameraErrorMessage(error);
      });
    } catch (error) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to open camera.';
      });
      Get.log('Failed to load cameras: $error', isError: true);
    }
  }

  Future<void> _initializeCamera(int index) async {
    if (_cameras.isEmpty) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    final oldController = _cameraController;
    _cameraController = null;
    await oldController?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraIndex = index;
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      await controller.dispose();
      setState(() {
        _isInitializing = false;
        _errorMessage = _cameraErrorMessage(error);
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      await _showImagePreview(image.path);
    } on CameraException catch (error) {
      Get.snackbar('Camera', _cameraErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    await _showImagePreview(image.path);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera(nextIndex);
  }

  Future<void> _showImagePreview(String path) async {
    await Get.dialog<void>(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: Get.back,
                      child: const Text('Retake'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back<void>();
                        Get.back<void>();
                      },
                      child: const Text('Done'),
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

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission is required to take photos.';
      default:
        return 'Failed to open camera.';
    }
  }
}

class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.isCapturing,
    required this.onPickGallery,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.canSwitchCamera,
  });

  final bool isCapturing;
  final VoidCallback onPickGallery;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final bool canSwitchCamera;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 104,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filled(
              onPressed: onPickGallery,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
              icon: const Icon(Icons.photo_library, color: Colors.white),
            ),
            GestureDetector(
              onTap: isCapturing ? null : onCapture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: isCapturing ? 30 : 58,
                    height: isCapturing ? 30 : 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCapturing
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: canSwitchCamera ? onSwitchCamera : null,
              icon: Icon(
                Icons.cameraswitch,
                color: canSwitchCamera ? Colors.white : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusFrame extends StatelessWidget {
  const _FocusFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        children: const [
          _CornerAlignment(alignment: Alignment.topLeft, quarterTurns: 0),
          _CornerAlignment(alignment: Alignment.topRight, quarterTurns: 1),
          _CornerAlignment(alignment: Alignment.bottomRight, quarterTurns: 2),
          _CornerAlignment(alignment: Alignment.bottomLeft, quarterTurns: 3),
          Center(
            child: SizedBox(
              width: 50,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white70, width: 4),
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerAlignment extends StatelessWidget {
  const _CornerAlignment({required this.alignment, required this.quarterTurns});

  final Alignment alignment;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: CustomPaint(size: const Size(64, 64), painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 10)
      ..quadraticBezierTo(0, 0, 10, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
