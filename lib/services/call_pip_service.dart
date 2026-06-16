import 'package:flutter/services.dart';
import 'package:get/get.dart';

class CallPipService extends GetxService {
  static const MethodChannel _channel = MethodChannel('app.call/pip');

  Future<void> setCallActive(bool active) async {
    try {
      await _channel.invokeMethod<void>('setCallActive', active);
    } on PlatformException catch (e) {
      Get.log('Unable to update PiP call state: ${e.message}', isError: true);
    }
  }

  Future<void> enterPip() async {
    try {
      await _channel.invokeMethod<void>('enterPip');
    } on PlatformException catch (e) {
      Get.log('Unable to enter PiP: ${e.message}', isError: true);
    }
  }
}
