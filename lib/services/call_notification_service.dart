import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/calls/presentation/controllers/call_controller.dart';
import 'call_service.dart';

class CallNotificationService extends GetxService with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('app.call/notification');

  final CallService _callService = Get.find<CallService>();
  final RxBool isForeground = true.obs;
  bool _hasAskedNotificationPermission = false;

  bool get shouldShowSystemNotifications => !isForeground.value;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isForeground.value = state == AppLifecycleState.resumed;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  Future<void> showOngoingCall({
    required String title,
    required String body,
    required bool isVideo,
    required bool audioEnabled,
    required bool videoEnabled,
    required bool isScreenSharing,
  }) async {
    try {
      await _ensureNotificationPermission();
      await _channel.invokeMethod<void>('showOngoingCall', {
        'title': title,
        'body': body,
        'isVideo': isVideo,
        'audioEnabled': audioEnabled,
        'videoEnabled': videoEnabled,
        'isScreenSharing': isScreenSharing,
      });
    } on PlatformException catch (e) {
      Get.log('Unable to show call notification: ${e.message}', isError: true);
    }
  }

  Future<void> showIncomingCall({
    required String callerName,
    required bool isVideo,
  }) async {
    try {
      await _ensureNotificationPermission();
      final typeLabel = isVideo ? 'video' : 'voice';
      await _channel.invokeMethod<void>('showIncomingCall', {
        'title': 'Incoming $typeLabel call',
        'body': callerName,
        'callerName': callerName,
        'isVideo': isVideo,
      });
    } on PlatformException catch (e) {
      Get.log(
        'Unable to show incoming call notification: ${e.message}',
        isError: true,
      );
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

  Future<void> stopIncomingCall() async {
    try {
      await _channel.invokeMethod<void>('stopIncomingCall');
    } on PlatformException catch (e) {
      Get.log(
        'Unable to stop incoming call notification: ${e.message}',
        isError: true,
      );
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'answerIncomingCall':
        if (_callService.isReceivingCall.value &&
            Get.isRegistered<CallController>()) {
          await Get.find<CallController>().answerIncomingCall();
        }
        break;
      case 'declineIncomingCall':
        if (_callService.isReceivingCall.value &&
            Get.isRegistered<CallController>()) {
          Get.find<CallController>().declineIncomingCall();
        }
        break;
      case 'openIncomingCallScreen':
        if (_callService.isReceivingCall.value &&
            Get.isRegistered<CallController>()) {
          Get.find<CallController>().openIncomingCallScreen();
        }
        break;
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
