import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../services/call_service.dart';
import '../../../../services/call_notification_service.dart';
import '../../../../services/call_overlay_service.dart';
import '../../../../services/call_pip_service.dart';
import '../views/call_screen.dart';
import '../views/incoming_call_screen.dart';
import 'dart:async';

class CallController extends GetxController {
  static const String _incomingCallRouteName = '/IncomingCallScreen';

  final CallService callService = Get.find<CallService>();
  final CallOverlayService _overlayService = Get.find<CallOverlayService>();
  final CallPipService _pipService = Get.find<CallPipService>();
  final CallNotificationService _notificationService =
      Get.find<CallNotificationService>();

  final RxString callDuration = '00:00'.obs;
  final RxBool isFullCallScreenVisible = false.obs;
  final RxBool isIncomingCallScreenVisible = false.obs;
  final RxBool isMinimizingToOverlay = false.obs;
  RxBool get isInPipMode => _pipService.isInPipMode;
  Timer? _callTimer;
  int _seconds = 0;
  Worker? _notificationVisibilityWorker;

  bool get _hasNavigator => Get.key.currentState != null;

  void _startTimer() {
    _seconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
      final secs = (_seconds % 60).toString().padLeft(2, '0');
      callDuration.value = '$minutes:$secs';
    });
  }

  void _stopTimer() {
    _callTimer?.cancel();
    callDuration.value = '00:00';
  }

  @override
  void onClose() {
    _stopTimer();
    _notificationVisibilityWorker?.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();

    // Listen for incoming calls
    ever(callService.isReceivingCall, (bool isReceiving) {
      if (isReceiving && callService.incomingCallData != null) {
        _presentIncomingCall();
      } else {
        _notificationService.stopIncomingCall();
        _closeIncomingCallScreen();
      }
    });

    // Listen for accepted/outgoing active calls
    ever(callService.isInCall, (bool isInCall) {
      if (isInCall) {
        _notificationService.stopIncomingCall();
        _startTimer();
        _pipService.setCallActive(
          callService.isVideoCall,
          audioEnabled: callService.isAudioEnabled.value,
          videoEnabled: callService.isVideoEnabled.value,
        );
        if (_notificationService.shouldShowSystemNotifications) {
          _showOrUpdateNotification();
        }
        openCallScreen();
      } else {
        _stopTimer();
        _overlayService.hideOverlay();
        _notificationService.stopIncomingCall();
        _notificationService.stopOngoingCall();
        _pipService.setCallActive(false);
        // If we are on the call screen, go back
        if (_hasNavigator &&
            (isFullCallScreenVisible.value ||
                Get.currentRoute == '/CallScreen')) {
          isFullCallScreenVisible.value = false;
          Get.back();
        }
      }
    });

    everAll(
      [
        callService.isAudioEnabled,
        callService.isVideoEnabled,
        callService.isScreenSharing,
      ],
      (_) {
        if (!callService.isInCall.value) return;
        _pipService.updateCallControls(
          audioEnabled: callService.isAudioEnabled.value,
          videoEnabled: callService.isVideoEnabled.value,
        );
        if (_notificationService.shouldShowSystemNotifications) {
          _showOrUpdateNotification();
        }
      },
    );

    _notificationVisibilityWorker = ever<bool>(
      _notificationService.isForeground,
      (_) => _syncCallNotificationsWithLifecycle(),
    );
  }

  void startCall(
    String userId, {
    bool video = true,
    bool isGroup = false,
    List<String>? participants,
  }) async {
    final didStart = await callService.makeCall(
      userId,
      video: video,
      isGroup: isGroup,
      participants: participants,
    );
    if (didStart) {
      openCallScreen();
    }
  }

  void openIncomingCallScreen() {
    if (!callService.isReceivingCall.value ||
        callService.incomingCallData == null) {
      return;
    }
    if (!_hasNavigator) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openIncomingCallScreen();
      });
      return;
    }
    if (callService.incomingCallData?['type'] == 'video') {
      unawaited(callService.prepareIncomingVideoPreview());
    }
    if (isIncomingCallScreenVisible.value ||
        Get.currentRoute == _incomingCallRouteName) {
      return;
    }
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    isIncomingCallScreenVisible.value = true;
    Get.to(
      () => const IncomingCallScreen(),
      routeName: _incomingCallRouteName,
    )?.whenComplete(() {
      isIncomingCallScreenVisible.value = false;
    });
  }

  Future<void> answerIncomingCall() async {
    if (!callService.isReceivingCall.value) return;
    final isVideo = callService.incomingCallData?['type'] == 'video';
    final isDirectNotificationAnswer =
        !isIncomingCallScreenVisible.value &&
        Get.currentRoute != _incomingCallRouteName;
    await _notificationService.stopIncomingCall();
    if (isVideo) {
      if (isDirectNotificationAnswer) {
        await _waitForForegroundBeforeVideoAnswer();
      }
      await callService.prepareIncomingVideoPreview();
    }
    final didAccept = await callService.acceptCall();
    if (!didAccept) {
      if (isVideo) {
        Future.microtask(openIncomingCallScreen);
      }
      return;
    }
    _closeIncomingCallScreen();
  }

  void declineIncomingCall() async {
    if (!callService.isReceivingCall.value) return;
    final shouldCloseIncomingScreen =
        isIncomingCallScreenVisible.value ||
        Get.currentRoute == _incomingCallRouteName;
    if (!shouldCloseIncomingScreen) {
      if (callService.incomingCallData?['type'] == 'video') {
        await callService.prepareIncomingVideoPreview();
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    _closeIncomingCallScreen();
    callService.declineCall();
  }

  void openCallScreen() {
    _overlayService.hideOverlay();
    if (!_hasNavigator) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openCallScreen();
      });
      return;
    }
    if (isFullCallScreenVisible.value || Get.currentRoute == '/CallScreen') {
      return;
    }
    isFullCallScreenVisible.value = true;
    Get.to(() => const CallScreen())?.whenComplete(() {
      isFullCallScreenVisible.value = false;
    });
  }

  void hideFullCallScreenForOverlay() {
    if (!callService.isInCall.value && !callService.isCalling.value) return;
    isMinimizingToOverlay.value = true;
    if (_hasNavigator &&
        (isFullCallScreenVisible.value || Get.currentRoute == '/CallScreen')) {
      Get.back();
    } else {
      showOverlayAfterCallScreenClosed();
    }
  }

  void showOverlayAfterCallScreenClosed() {
    isFullCallScreenVisible.value = false;
    isMinimizingToOverlay.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isFullCallScreenVisible.value &&
          (callService.isInCall.value || callService.isCalling.value)) {
        _overlayService.showOverlay();
      }
    });
  }

  void _closeIncomingCallScreen() {
    if (!_hasNavigator) {
      isIncomingCallScreenVisible.value = false;
      return;
    }
    if (isIncomingCallScreenVisible.value ||
        Get.currentRoute == _incomingCallRouteName) {
      isIncomingCallScreenVisible.value = false;
      Get.back();
    }
  }

  Future<void> enterPip() async {
    if (callService.isInCall.value && callService.isVideoCall) {
      final didEnter = await _pipService.enterPip();
      if (!didEnter) {
        Get.snackbar(
          'PiP unavailable',
          'Your device or current screen did not allow picture-in-picture.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void _showOrUpdateNotification() {
    if (!callService.isInCall.value) return;
    final typeLabel = callService.isVideoCall ? 'Video call' : 'Voice call';
    final remoteName = callService.callDisplayName;
    _notificationService.showOngoingCall(
      title: typeLabel,
      body: '$remoteName • ongoing',
      isVideo: callService.isVideoCall,
      audioEnabled: callService.isAudioEnabled.value,
      videoEnabled: callService.isVideoEnabled.value,
      isScreenSharing: callService.isScreenSharing.value,
    );
  }

  void _presentIncomingCall() {
    if (_notificationService.shouldShowSystemNotifications) {
      _showIncomingCallNotification();
      return;
    }

    unawaited(_notificationService.stopIncomingCall());
    Future.microtask(openIncomingCallScreen);
  }

  void _showIncomingCallNotification() {
    if (!_notificationService.shouldShowSystemNotifications) return;

    final isVideo = callService.incomingCallData?['type'] == 'video';
    _notificationService.showIncomingCall(
      callerName: callService.callDisplayName,
      isVideo: isVideo,
    );
  }

  void _syncCallNotificationsWithLifecycle() {
    if (!_notificationService.shouldShowSystemNotifications) {
      unawaited(_notificationService.stopIncomingCall());
      unawaited(_notificationService.stopOngoingCall());
      if (callService.isReceivingCall.value) {
        Future.microtask(openIncomingCallScreen);
      }
      return;
    }

    if (callService.isReceivingCall.value &&
        callService.incomingCallData != null) {
      _showIncomingCallNotification();
      return;
    }

    if (callService.isInCall.value) {
      _showOrUpdateNotification();
    }
  }

  Future<void> _waitForForegroundBeforeVideoAnswer() async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
