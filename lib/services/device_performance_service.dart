import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

enum DevicePerformanceProfile {
  low,
  mid,
  high;

  static DevicePerformanceProfile fromString(String? value) {
    switch (value) {
      case 'low':
        return DevicePerformanceProfile.low;
      case 'mid':
        return DevicePerformanceProfile.mid;
      case 'high':
        return DevicePerformanceProfile.high;
      default:
        return DevicePerformanceProfile.high;
    }
  }
}

class CameraMediaPreset {
  const CameraMediaPreset({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.maxBitrate,
  });

  final int width;
  final int height;
  final int frameRate;
  final int maxBitrate;
}

class ScreenShareMediaPreset {
  const ScreenShareMediaPreset({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.maxBitrate,
    required this.maxFramerate,
    required this.renderLocalPreview,
  });

  final int width;
  final int height;
  final int frameRate;
  final int maxBitrate;
  final int maxFramerate;
  final bool renderLocalPreview;
}

class DevicePerformanceService extends GetxService {
  static const MethodChannel _channel = MethodChannel('app.device/performance');

  final Rx<DevicePerformanceProfile> profile =
      DevicePerformanceProfile.high.obs;
  final RxMap<String, dynamic> deviceInfo = <String, dynamic>{}.obs;

  Future<DevicePerformanceService> init() async {
    await refresh();
    return this;
  }

  Future<void> refresh() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      profile.value = DevicePerformanceProfile.high;
      return;
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceProfile',
      );
      final info = Map<String, dynamic>.from(result ?? const {});
      deviceInfo.assignAll(info);
      profile.value = DevicePerformanceProfile.fromString(
        info['profile']?.toString(),
      );
      Get.log(
        'Android device performance profile: ${profile.value.name} $info',
      );
    } catch (e) {
      profile.value = DevicePerformanceProfile.high;
      Get.log(
        'Unable to load Android device performance profile; using high defaults: $e',
        isError: true,
      );
    }
  }

  bool get isLowProfile => profile.value == DevicePerformanceProfile.low;
  bool get isMidProfile => profile.value == DevicePerformanceProfile.mid;
  bool get shouldReduceFlutterVideoLoad => isLowProfile;

  CameraMediaPreset get cameraPreset {
    switch (profile.value) {
      case DevicePerformanceProfile.low:
        return const CameraMediaPreset(
          width: 640,
          height: 360,
          frameRate: 15,
          maxBitrate: 350000,
        );
      case DevicePerformanceProfile.mid:
        return const CameraMediaPreset(
          width: 640,
          height: 480,
          frameRate: 20,
          maxBitrate: 500000,
        );
      case DevicePerformanceProfile.high:
        return const CameraMediaPreset(
          width: 640,
          height: 480,
          frameRate: 30,
          maxBitrate: 900000,
        );
    }
  }

  ScreenShareMediaPreset screenSharePreset({required bool fullScreenOnly}) {
    switch (profile.value) {
      case DevicePerformanceProfile.low:
        return fullScreenOnly
            ? const ScreenShareMediaPreset(
                width: 540,
                height: 304,
                frameRate: 5,
                maxBitrate: 180000,
                maxFramerate: 5,
                renderLocalPreview: false,
              )
            : const ScreenShareMediaPreset(
                width: 640,
                height: 360,
                frameRate: 5,
                maxBitrate: 220000,
                maxFramerate: 5,
                renderLocalPreview: false,
              );
      case DevicePerformanceProfile.mid:
        return fullScreenOnly
            ? const ScreenShareMediaPreset(
                width: 720,
                height: 405,
                frameRate: 6,
                maxBitrate: 260000,
                maxFramerate: 6,
                renderLocalPreview: true,
              )
            : const ScreenShareMediaPreset(
                width: 854,
                height: 480,
                frameRate: 8,
                maxBitrate: 300000,
                maxFramerate: 8,
                renderLocalPreview: true,
              );
      case DevicePerformanceProfile.high:
        return const ScreenShareMediaPreset(
          width: 960,
          height: 540,
          frameRate: 12,
          maxBitrate: 300000,
          maxFramerate: 6,
          renderLocalPreview: true,
        );
    }
  }
}
