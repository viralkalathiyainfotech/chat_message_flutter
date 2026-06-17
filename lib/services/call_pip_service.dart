import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'call_service.dart';

class CallPipService extends GetxService {
  static const MethodChannel _channel = MethodChannel('app.call/pip');

  final RxBool isInPipMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPipModeChanged':
          isInPipMode.value = call.arguments as bool? ?? false;
          break;
        case 'toggleAudio':
          if (Get.isRegistered<CallService>()) {
            final callService = Get.find<CallService>();
            callService.toggleAudio();
            await updateCallControls(
              audioEnabled: callService.isAudioEnabled.value,
              videoEnabled: callService.isVideoEnabled.value,
            );
          }
          break;
        case 'toggleVideo':
          if (Get.isRegistered<CallService>()) {
            final callService = Get.find<CallService>();
            callService.toggleVideo();
            await updateCallControls(
              audioEnabled: callService.isAudioEnabled.value,
              videoEnabled: callService.isVideoEnabled.value,
            );
          }
          break;
        case 'hangupCall':
          if (Get.isRegistered<CallService>()) {
            final callService = Get.find<CallService>();
            if (callService.isInCall.value || callService.isCalling.value) {
              callService.endCall();
            }
          }
          break;
      }
    });
  }

  Future<void> setCallActive(
    bool active, {
    bool audioEnabled = true,
    bool videoEnabled = true,
  }) async {
    try {
      await _channel.invokeMethod<void>('setCallActive', {
        'active': active,
        'audioEnabled': audioEnabled,
        'videoEnabled': videoEnabled,
      });
      if (!active) {
        isInPipMode.value = false;
      }
    } on PlatformException catch (e) {
      Get.log('Unable to update PiP call state: ${e.message}', isError: true);
    }
  }

  Future<void> updateCallControls({
    required bool audioEnabled,
    required bool videoEnabled,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateCallControls', {
        'audioEnabled': audioEnabled,
        'videoEnabled': videoEnabled,
      });
    } on PlatformException catch (e) {
      Get.log('Unable to update PiP controls: ${e.message}', isError: true);
    }
  }

  Future<bool> enterPip() async {
    try {
      if (Get.isRegistered<CallService>()) {
        final callService = Get.find<CallService>();
        await updateCallControls(
          audioEnabled: callService.isAudioEnabled.value,
          videoEnabled: callService.isVideoEnabled.value,
        );
      }
      return await _channel.invokeMethod<bool>('enterPip') ?? false;
    } on PlatformException catch (e) {
      Get.log('Unable to enter PiP: ${e.message}', isError: true);
      return false;
    }
  }
}
