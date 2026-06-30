import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'call_service.dart';
import 'socket_service.dart';
import 'storage_service.dart';

class RemoteControlService extends GetxService {
  static const MethodChannel _channel = MethodChannel(
    'app.remote_control/accessibility',
  );

  final SocketService _socketService = Get.find<SocketService>();
  final CallService _callService = Get.find<CallService>();
  final StorageService _storageService = Get.find<StorageService>();

  final RxBool hasControl = false.obs;
  final RxBool remoteScreenSharing = false.obs;
  final RxBool isAccessibilityEnabled = false.obs;
  final RxString controllingHostId = ''.obs;
  final RxString grantedControllerId = ''.obs;
  Worker? _callStateWorker;
  Future<void> _controlEventQueue = Future<void>.value();

  @override
  void onInit() {
    super.onInit();
    _socketService.onControlRequest = _handleControlRequest;
    _socketService.onControlPermission = _handleControlPermission;
    _socketService.onControlEvent = _handleControlEvent;
    _socketService.onControlRevoked = _handleControlRevoked;
    _socketService.onControlRevokedForHost = _handleControlRevokedForHost;
    _socketService.onCallScreenShareState = _handleScreenShareState;
    _callStateWorker = ever<bool>(_callService.isInCall, (inCall) {
      if (!inCall) _resetState();
    });
    unawaited(refreshAccessibilityStatus());
  }

  @override
  void onClose() {
    _callStateWorker?.dispose();
    super.onClose();
  }

  Future<void> refreshAccessibilityStatus() async {
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'isAccessibilityEnabled',
      );
      isAccessibilityEnabled.value = enabled == true;
    } catch (e) {
      Get.log('Unable to check remote control accessibility: $e');
      isAccessibilityEnabled.value = false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  void requestControl() {
    final hostId = _callService.remoteUserId;
    final roomId = _callService.currentRoomId;
    if (!_callService.isInCall.value || hostId == null || roomId == null) {
      _showRemoteControlMessage('Remote control is available during a call.');
      return;
    }
    if (!remoteScreenSharing.value) {
      _showRemoteControlMessage(
        'Remote control is available when the other device is sharing screen.',
      );
      return;
    }

    _socketService.emitRequestControl({'hostId': hostId, 'roomId': roomId});
    _showRemoteControlMessage('Remote control request sent.');
  }

  void revokeControl() {
    final viewerId = grantedControllerId.value;
    final roomId = _callService.currentRoomId;
    if (viewerId.isNotEmpty) {
      _socketService.emitRevokeControl({
        'viewerId': viewerId,
        'roomId': roomId,
      });
    }
    grantedControllerId.value = '';
  }

  void stopControlling() {
    hasControl.value = false;
    controllingHostId.value = '';
  }

  void sendTap({required double normalizedX, required double normalizedY}) {
    _sendControlEvent('tap', {
      'x': normalizedX.clamp(0.0, 1.0),
      'y': normalizedY.clamp(0.0, 1.0),
    });
  }

  void sendSwipe({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    int durationMs = 220,
  }) {
    _sendControlEvent('swipe', {
      'startX': startX.clamp(0.0, 1.0),
      'startY': startY.clamp(0.0, 1.0),
      'endX': endX.clamp(0.0, 1.0),
      'endY': endY.clamp(0.0, 1.0),
      'durationMs': durationMs,
    });
  }

  void sendBack() {
    _sendControlEvent('globalAction', {'action': 'back'});
  }

  void sendHome() {
    _sendControlEvent('globalAction', {'action': 'home'});
  }

  void sendRecents() {
    _sendControlEvent('globalAction', {'action': 'recents'});
  }

  void _sendControlEvent(String type, Map<String, dynamic> payload) {
    final roomId = _callService.currentRoomId;
    if (!hasControl.value || !remoteScreenSharing.value || roomId == null) {
      return;
    }
    _socketService.emitControlEvent({
      'roomId': roomId,
      'type': type,
      'payload': payload,
    });
  }

  Future<void> _handleControlRequest(Map<String, dynamic> data) async {
    final viewerId = data['viewerId']?.toString();
    if (viewerId == null || viewerId.isEmpty) return;

    if (!_callService.isScreenSharing.value) {
      _socketService.emitRevokeControl({
        'viewerId': viewerId,
        'roomId': data['roomId'],
      });
      _showRemoteControlMessage(
        'Start screen sharing before allowing remote control.',
      );
      return;
    }

    await refreshAccessibilityStatus();
    if (!isAccessibilityEnabled.value) {
      final shouldOpen = await _confirm(
        title: 'Remote control',
        message:
            'A participant wants to control this device. Enable Accessibility permission to allow it.',
        confirmText: 'Open settings',
      );
      if (shouldOpen) await openAccessibilitySettings();
      _socketService.emitRevokeControl({
        'viewerId': viewerId,
        'roomId': data['roomId'],
      });
      return;
    }

    final allowed = await _confirm(
      title: 'Allow remote control?',
      message: 'A participant wants to control this device during the call.',
      confirmText: 'Allow',
    );

    if (allowed) {
      grantedControllerId.value = viewerId;
      _socketService.emitGrantControl({
        'viewerId': viewerId,
        'roomId': data['roomId'],
      });
    } else {
      _socketService.emitRevokeControl({
        'viewerId': viewerId,
        'roomId': data['roomId'],
      });
    }
  }

  void _handleControlPermission(Map<String, dynamic> data) {
    final grantedValue = data['granted'];
    final granted =
        (grantedValue == true || data['value'] == true) &&
        remoteScreenSharing.value;
    hasControl.value = granted;
    controllingHostId.value = granted ? (_callService.remoteUserId ?? '') : '';
    _showRemoteControlMessage(
      granted ? 'Remote control granted.' : 'Remote control revoked.',
    );
  }

  Future<void> _handleControlEvent(Map<String, dynamic> data) async {
    _controlEventQueue = _controlEventQueue
        .catchError((_) {})
        .then((_) => _performControlEvent(data));
    await _controlEventQueue;
  }

  Future<void> _performControlEvent(Map<String, dynamic> data) async {
    final from = data['from']?.toString();
    if (from == null ||
        grantedControllerId.value.isEmpty ||
        from != grantedControllerId.value) {
      return;
    }

    final type = data['type']?.toString();
    final payload = data['payload'];
    if (type == null || payload is! Map) return;
    final args = Map<String, dynamic>.from(payload);

    switch (type) {
      case 'tap':
      case 'click':
      case 'doubleClick':
        await _tap(args);
        if (type == 'doubleClick') {
          await Future<void>.delayed(const Duration(milliseconds: 90));
          await _tap(args);
        }
        break;
      case 'swipe':
      case 'dragEnd':
        await _swipe(args);
        break;
      case 'globalAction':
        final action = args['action']?.toString();
        if (action != null) {
          await _channel.invokeMethod<bool>('globalAction', {'action': action});
        }
        break;
      case 'setText':
        final text = args['text']?.toString();
        if (text != null) {
          await _channel.invokeMethod<bool>('setText', {'text': text});
        }
        break;
    }
  }

  void _handleControlRevoked(dynamic _) {
    hasControl.value = false;
    controllingHostId.value = '';
  }

  void _handleControlRevokedForHost(Map<String, dynamic> data) {
    final viewerId = data['viewerId']?.toString();
    if (viewerId == null || viewerId == grantedControllerId.value) {
      grantedControllerId.value = '';
    }
  }

  void _handleScreenShareState(Map<String, dynamic> data) {
    final senderId = data['from']?.toString();
    if (senderId == null || senderId == _storageService.getUserId()) return;

    final isSharing = data['isSharing'] == true;
    remoteScreenSharing.value = isSharing;
    if (!isSharing) {
      hasControl.value = false;
      controllingHostId.value = '';
    }
  }

  Future<void> _tap(Map<String, dynamic> args) async {
    final point = _pointFromPayload(args['x'], args['y']);
    if (point == null) return;
    await _channel.invokeMethod<bool>('tap', {'x': point.dx, 'y': point.dy});
  }

  Future<void> _swipe(Map<String, dynamic> args) async {
    final start = _pointFromPayload(args['startX'], args['startY']);
    final end = _pointFromPayload(args['endX'], args['endY']);
    if (start == null || end == null) return;
    await _channel.invokeMethod<bool>('swipe', {
      'startX': start.dx,
      'startY': start.dy,
      'endX': end.dx,
      'endY': end.dy,
      'durationMs': _num(args['durationMs'])?.round() ?? 220,
    });
  }

  Offset? _pointFromPayload(dynamic xValue, dynamic yValue) {
    final x = _num(xValue);
    final y = _num(yValue);
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  double? _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(confirmText),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    return result == true;
  }

  void _showRemoteControlMessage(String message) {
    Get.snackbar('Remote control', message);
  }

  void _resetState() {
    hasControl.value = false;
    remoteScreenSharing.value = false;
    controllingHostId.value = '';
    grantedControllerId.value = '';
  }
}
