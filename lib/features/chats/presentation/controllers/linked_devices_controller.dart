import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../../constants/network_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../services/socket_service.dart';
import '../../../../services/storage_service.dart';

class LinkedDevice {
  const LinkedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    this.lastLogin,
  });

  final String deviceId;
  final String deviceName;
  final String deviceType;
  final DateTime? lastLogin;

  factory LinkedDevice.fromJson(Map<String, dynamic> json) {
    return LinkedDevice(
      deviceId: _readString(json['deviceId']),
      deviceName: _readString(json['deviceName'], fallback: 'Unknown device'),
      deviceType: _readString(json['deviceType'], fallback: 'desktop'),
      lastLogin: _readDate(json['lastLogin']),
    );
  }

  bool get isDesktop => deviceType.toLowerCase() == 'desktop';

  static String _readString(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return fallback;
    return text;
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }
}

class LinkedDevicesController extends GetxController {
  LinkedDevicesController({
    ApiService? apiService,
    StorageService? storageService,
  }) : _apiService = apiService ?? Get.find<ApiService>(),
       _storageService = storageService ?? Get.find<StorageService>();

  final ApiService _apiService;
  final StorageService _storageService;

  final RxBool isLoading = false.obs;
  final RxBool isLinking = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString loggingOutDeviceId = ''.obs;
  final RxList<LinkedDevice> devices = <LinkedDevice>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDevices();
  }

  Future<void> loadDevices({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _apiService.dio.get(NetworkConstants.devices);
      final data = response.data;
      final rawDevices = data is Map ? data['devices'] : data;
      final currentDeviceId = _storageService.getString('deviceId');

      final linkedDevices = <LinkedDevice>[];
      if (rawDevices is List) {
        for (final rawDevice in rawDevices) {
          if (rawDevice is! Map) continue;
          final device = LinkedDevice.fromJson(_stringKeyedMap(rawDevice));
          if (device.deviceId.isEmpty) continue;
          if (currentDeviceId != null && device.deviceId == currentDeviceId) {
            continue;
          }
          linkedDevices.add(device);
        }
      }

      linkedDevices.sort((a, b) {
        final aTime = a.lastLogin ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastLogin ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      devices.assignAll(linkedDevices);
    } on DioException catch (error) {
      errorMessage.value = _messageFromDio(
        error,
        'Failed to load linked devices.',
      );
    } catch (error) {
      errorMessage.value = 'Failed to load linked devices.';
      Get.log('Linked devices load failed: $error', isError: true);
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<bool> linkDeviceFromQr(String rawValue) async {
    _QrLoginData qrLoginData;
    try {
      qrLoginData = _parseQrLoginData(rawValue);
    } on _QrLoginException catch (error) {
      _showError(error.message);
      return false;
    }

    isLinking.value = true;
    try {
      final response = await _apiService.dio.post(
        NetworkConstants.qrLogin,
        data: {
          'qrData': {
            'sessionId': qrLoginData.sessionId,
            'timestamp': qrLoginData.timestamp,
          },
          'deviceInfo': qrLoginData.deviceInfo,
        },
      );

      _emitQrScanSuccess(qrLoginData.sessionId, response.data);
      await loadDevices(showLoading: false);
      Get.snackbar('Linked device', 'Device linked successfully.');
      return true;
    } on DioException catch (error) {
      final message = _messageFromDio(error, 'Login failed. Please try again.');
      _emitQrScanError(qrLoginData.sessionId, message);
      _showError(message);
      return false;
    } catch (error) {
      const message = 'Login failed. Please try again.';
      _emitQrScanError(qrLoginData.sessionId, message);
      _showError(message);
      Get.log('QR login failed: $error', isError: true);
      return false;
    } finally {
      isLinking.value = false;
    }
  }

  Future<void> logoutDevice(LinkedDevice device) async {
    if (device.deviceId.isEmpty) return;

    loggingOutDeviceId.value = device.deviceId;
    try {
      final response = await _apiService.dio.post(
        NetworkConstants.logoutDevice,
        data: {'deviceId': device.deviceId},
      );

      final success =
          response.statusCode == 200 ||
          (response.data is Map && response.data['status'] == 200);
      if (success) {
        devices.removeWhere((item) => item.deviceId == device.deviceId);
        Get.snackbar('Linked device', '${device.deviceName} logged out.');
      } else {
        _showError('Failed to logout device.');
      }
    } on DioException catch (error) {
      _showError(_messageFromDio(error, 'Failed to logout device.'));
    } catch (error) {
      _showError('Failed to logout device.');
      Get.log('Device logout failed: $error', isError: true);
    } finally {
      loggingOutDeviceId.value = '';
    }
  }

  String formatLastActive(LinkedDevice device) {
    final lastLogin = device.lastLogin;
    if (lastLogin == null) return 'Last active unknown';

    final now = DateTime.now();
    final time =
        '${_hour12(lastLogin)}:${lastLogin.minute.toString().padLeft(2, '0')} ${lastLogin.hour >= 12 ? 'PM' : 'AM'}';

    final sameDay =
        now.year == lastLogin.year &&
        now.month == lastLogin.month &&
        now.day == lastLogin.day;

    if (sameDay) return 'Last active today at $time';

    final yesterday = now.subtract(const Duration(days: 1));
    final wasYesterday =
        yesterday.year == lastLogin.year &&
        yesterday.month == lastLogin.month &&
        yesterday.day == lastLogin.day;
    if (wasYesterday) return 'Last active yesterday at $time';

    return 'Last active ${lastLogin.day.toString().padLeft(2, '0')}/${lastLogin.month.toString().padLeft(2, '0')}/${lastLogin.year} at $time';
  }

  int _hour12(DateTime date) {
    final hour = date.hour % 12;
    return hour == 0 ? 12 : hour;
  }

  _QrLoginData _parseQrLoginData(String rawValue) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawValue);
    } catch (_) {
      throw const _QrLoginException('Scan failed: Invalid QR code format.');
    }

    if (decoded is! Map) {
      throw const _QrLoginException('Scan failed: Invalid QR code format.');
    }

    final qrData = _stringKeyedMap(decoded);
    if (qrData['action']?.toString() != 'login') {
      throw const _QrLoginException('Scan failed: Invalid QR code type.');
    }

    final sessionId = qrData['sessionId']?.toString().trim();
    final timestamp = qrData['timestamp']?.toString().trim();
    if (sessionId == null ||
        sessionId.isEmpty ||
        timestamp == null ||
        timestamp.isEmpty) {
      throw const _QrLoginException(
        'Scan failed: QR code is missing required data.',
      );
    }

    final qrTime = DateTime.tryParse(timestamp);
    if (qrTime == null) {
      throw const _QrLoginException('Scan failed: Invalid QR code timestamp.');
    }

    if (DateTime.now().difference(qrTime.toLocal()) >
        const Duration(minutes: 5)) {
      throw const _QrLoginException('Scan failed: QR code has expired.');
    }

    final deviceInfo = _stringKeyedMap(qrData['deviceInfo']);
    final deviceId = deviceInfo['deviceId']?.toString().trim();
    if (deviceId == null || deviceId.isEmpty || deviceId == 'null') {
      throw const _QrLoginException(
        'Scan failed: Refresh the desktop QR code and try again.',
      );
    }

    return _QrLoginData(
      sessionId: sessionId,
      timestamp: timestamp,
      deviceInfo: deviceInfo,
    );
  }

  static Map<String, dynamic> _stringKeyedMap(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _messageFromDio(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    return fallback;
  }

  void _showError(String message) {
    Get.snackbar('Linked device', message);
  }

  void _emitQrScanSuccess(String sessionId, Object? responseData) {
    final socket = Get.isRegistered<SocketService>()
        ? Get.find<SocketService>().socket
        : null;
    if (socket == null) return;

    final data = _stringKeyedMap(responseData);
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) return;

    socket.emit('qr-scan-success', {
      'sessionId': sessionId,
      'token': token,
      'userId': data['userId']?.toString(),
      'username': data['username']?.toString(),
      'userData': data['userData'],
    });
  }

  void _emitQrScanError(String sessionId, String message) {
    final socket = Get.isRegistered<SocketService>()
        ? Get.find<SocketService>().socket
        : null;
    socket?.emit('qr-scan-error', {'sessionId': sessionId, 'message': message});
  }
}

class _QrLoginData {
  const _QrLoginData({
    required this.sessionId,
    required this.timestamp,
    required this.deviceInfo,
  });

  final String sessionId;
  final String timestamp;
  final Map<String, dynamic> deviceInfo;
}

class _QrLoginException implements Exception {
  const _QrLoginException(this.message);

  final String message;
}
