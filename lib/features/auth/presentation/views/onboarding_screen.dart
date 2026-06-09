import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart' hide ContextExtensionss;
import '../../../../core/routes/app_routes.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/string_constants.dart';
import '../../../../constants/asset_constants.dart';
import '../../../../core/extensions/app_extensions.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundDarkMode,
      body: Stack(
        children: [
          // Full screen background image
          Positioned.fill(
            child: Image.asset(
              AssetConstants.onboardingBackground, 
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
          // Foreground content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  const Text(
                    StringConstants.onboardingTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: ColorConstants.white),
                  ),
                  16.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        AssetConstants.checkShieldIcon,
                        width: 20,
                        height: 20,
                        // colorFilter: const ColorFilter.mode(Colors.green, BlendMode.srcIn),
                      ),
                      8.width,
                      Text(
                        StringConstants.secureMessaging,
                        style: const TextStyle(color: ColorConstants.textSecondary, fontSize: 16),
                      ),
                    ],
                  ),
                  40.height,
                  SwipeToStartButton(
                    onSwipe: () => Get.offAllNamed(AppRoutes.login),
                  ),
                  20.height,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SwipeToStartButton extends StatefulWidget {
  final VoidCallback onSwipe;

  const SwipeToStartButton({super.key, required this.onSwipe});

  @override
  State<SwipeToStartButton> createState() => _SwipeToStartButtonState();
}

class _SwipeToStartButtonState extends State<SwipeToStartButton> {
  double _dragPosition = 0;
  bool _isFinished = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        const double buttonWidth = 60.0;
        final double maxDragPosition = maxWidth - buttonWidth;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              const Center(
                child: Text(
                  StringConstants.startMessaging, 
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
              AnimatedPositioned(
                duration: _dragPosition == 0 ? const Duration(milliseconds: 300) : Duration.zero,
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isFinished) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDragPosition) _dragPosition = maxDragPosition;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isFinished) return;
                    if (_dragPosition > maxDragPosition * 0.8) {
                      setState(() {
                        _dragPosition = maxDragPosition;
                        _isFinished = true;
                      });
                      widget.onSwipe();
                    } else {
                      setState(() {
                        _dragPosition = 0;
                      });
                    }
                  },
                  child: Padding(
                    padding: 8.0.all,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: ColorConstants.primaryBlue, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
