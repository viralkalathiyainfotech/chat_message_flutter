import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/calls/presentation/controllers/call_controller.dart';
import 'call_service.dart';

class CallNotificationService extends GetxService {
  static const MethodChannel _channel = MethodChannel('app.call/notification');

  final CallService _callService = Get.find<CallService>();
  bool _hasAskedNotificationPermission = false;

  @override
  void onInit() {
    super.onInit();
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> showOngoingCall({
    required String title,
    required String body,
    required bool isVideo,
    required bool audioEnabled,
    required bool videoEnabled,
  }) async {
    try {
      await _ensureNotificationPermission();
      await _channel.invokeMethod<void>('showOngoingCall', {
        'title': title,
        'body': body,
        'isVideo': isVideo,
        'audioEnabled': audioEnabled,
        'videoEnabled': videoEnabled,
      });
    } on PlatformException catch (e) {
      Get.log('Unable to show call notification: ${e.message}', isError: true);
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (!Platform.isAndroid || _hasAskedNotificationPermission) return;
    _hasAskedNotificationPermission = true;
    await Permission.notification.request();
  }

  Future<void> stopOngoingCall() async {
    try {
      await _channel.invokeMethod<void>('stopOngoingCall');
    } on PlatformException catch (e) {
      Get.log('Unable to stop call notification: ${e.message}', isError: true);
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'hangupCall':
        if (_callService.isInCall.value || _callService.isCalling.value) {
          _callService.endCall();
        }
        break;
      case 'toggleAudio':
        if (_callService.isInCall.value || _callService.isCalling.value) {
          _callService.toggleAudio();
        }
        break;
      case 'toggleVideo':
        if (_callService.isInCall.value || _callService.isCalling.value) {
          _callService.toggleVideo();
        }
        break;
      case 'openCallScreen':
        if (Get.isRegistered<CallController>()) {
          Get.find<CallController>().openCallScreen();
        }
        break;
      default:
        Get.log('Unknown call notification method: ${call.method}');
    }
  }
}
