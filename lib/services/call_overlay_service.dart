import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CallOverlayService extends GetxService {
  OverlayEntry? _overlayEntry;
  final RxBool isVisible = false.obs;
  final Rx<Offset> position = const Offset(18, 96).obs;

  bool get isShowing => isVisible.value;

  void showOverlay() {
    isVisible.value = true;
    Get.log('Call overlay requested');
  }

  void updatePosition(Offset nextPosition) {
    position.value = nextPosition;
  }

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    isVisible.value = false;
  }

  @override
  void onClose() {
    hideOverlay();
    super.onClose();
  }
}
