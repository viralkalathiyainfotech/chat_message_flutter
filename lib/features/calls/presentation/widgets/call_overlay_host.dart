import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../services/call_overlay_service.dart';
import 'floating_call_widget.dart';

class CallOverlayHost extends StatelessWidget {
  const CallOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final overlayService = Get.find<CallOverlayService>();

    return Stack(
      children: [
        child,
        Obx(() {
          if (!overlayService.isVisible.value) {
            return const SizedBox.shrink();
          }

          return FloatingCallWidget(
            key: const ValueKey('root-floating-call-widget'),
            initialPosition: overlayService.position.value,
            onPositionChanged: overlayService.updatePosition,
          );
        }),
      ],
    );
  }
}
