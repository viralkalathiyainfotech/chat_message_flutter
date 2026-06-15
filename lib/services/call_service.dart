import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;
import 'package:uuid/uuid.dart';
import 'socket_service.dart';
import 'storage_service.dart';

class CallService extends GetxService {
  final SocketService _socketService = Get.find<SocketService>();
  final StorageService _storageService = Get.find<StorageService>();
  
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  // Reactive states
  final RxBool isCalling = false.obs;
  final RxBool isReceivingCall = false.obs;
  final RxBool isInCall = false.obs;
  final RxBool isVideoEnabled = true.obs;
  final RxBool isAudioEnabled = true.obs;
  final RxBool isScreenSharing = false.obs;
  
  final RxBool hasLocalStream = false.obs;
  final RxBool hasRemoteStream = false.obs;
  
  final Rx<RTCVideoRenderer> localRenderer = RTCVideoRenderer().obs;
  final Rx<RTCVideoRenderer> remoteRenderer = RTCVideoRenderer().obs;

  String? currentRoomId;
  String? remoteUserId;
  Map<String, dynamic>? incomingCallData;
  DateTime? callStartTime;
  bool isIncoming = false;
  bool isVideoCall = false;

  @override
  void onInit() {
    super.onInit();
    _setupSocketListeners();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await localRenderer.value.initialize();
    await remoteRenderer.value.initialize();
  }

  void _setupSocketListeners() {
    _socketService.onIncomingCall = (data) {
      if (isInCall.value || isCalling.value) {
        // Already in a call, backend should handle user-in-call, but we can ignore
        return;
      }
      incomingCallData = data;
      remoteUserId = data['fromEmail'];
      currentRoomId = data['roomId'];
      isIncoming = true;
      isVideoCall = data['type'] == 'video';
      isReceivingCall.value = true;
    };

    _socketService.onCallAccepted = (data) async {
      final signal = data['signal'];
      if (signal != null && _peerConnection != null) {
        if (signal['type'] == 'answer') {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(signal['sdp'], signal['type'])
          );
        }
      }
      isCalling.value = false;
      isInCall.value = true;
      callStartTime = DateTime.now();
    };

    _socketService.onCallSignal = (data) async {
      final signal = data['signal'];
      if (signal != null && _peerConnection != null) {
        if (signal['type'] == 'candidate' || signal['candidate'] != null) {
          final candidateMap = signal['candidate'] ?? signal;
          await _peerConnection!.addCandidate(
            RTCIceCandidate(
              candidateMap['candidate'],
              candidateMap['sdpMid'],
              candidateMap['sdpMLineIndex'] ?? 0,
            )
          );
        } else if (signal['type'] == 'offer' || signal['type'] == 'answer') {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(signal['sdp'], signal['type'])
          );
        }
      }
    };

    _socketService.onEndCall = (data) {
      endCallLocally();
    };

    _socketService.onUserInCall = (data) {
      final message = data['message'] ?? 'User is currently in another call';
      Get.snackbar('Call Failed', message, backgroundColor: Colors.red, colorText: Colors.white);
      endCallLocally();
    };
  }

  Future<void> makeCall(String targetUserId, {bool video = true}) async {
    remoteUserId = targetUserId;
    currentRoomId = const Uuid().v4();
    isCalling.value = true;
    isIncoming = false;
    isVideoCall = video;
    
    await _setupPeerConnection(video: video);
    
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _socketService.emitCallRequest({
      'fromEmail': _storageService.getUserId(),
      'toEmail': remoteUserId,
      'signal': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'type': video ? 'video' : 'audio',
      'isGroupCall': false,
      'participants': [_storageService.getUserId(), remoteUserId],
      'roomId': currentRoomId,
    });
  }

  Future<void> acceptCall() async {
    if (incomingCallData == null) return;
    
    final bool isVideo = incomingCallData!['type'] == 'video';
    await _setupPeerConnection(video: isVideo);

    final signal = incomingCallData!['signal'];
    if (signal != null && signal['type'] == 'offer') {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(signal['sdp'], signal['type'])
      );
    }

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socketService.emitCallAccept({
      'signal': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
      'fromEmail': incomingCallData!['fromEmail'], // The original caller
      'toEmail': _storageService.getUserId(), // The user accepting
      'participants': incomingCallData!['participants'] ?? [_storageService.getUserId(), incomingCallData!['fromEmail']],
      'roomId': currentRoomId,
    });

    isReceivingCall.value = false;
    isInCall.value = true;
    callStartTime = DateTime.now();
  }

  void declineCall() {
    _socketService.emitEndCall({
      'to': remoteUserId,
      'from': _storageService.getUserId(),
      'roomId': currentRoomId,
    });
    _resetCallState();
  }

  void endCall() {
    _socketService.emitEndCall({
      'to': remoteUserId,
      'from': _storageService.getUserId(),
      'roomId': currentRoomId,
    });
    endCallLocally();
  }

  void endCallLocally() {
    if (!isIncoming && remoteUserId != null) {
      final duration = callStartTime != null ? DateTime.now().difference(callStartTime!).inSeconds : 0;
      _socketService.emitSaveCallMessage({
        'senderId': _storageService.getUserId(),
        'receiverId': remoteUserId,
        'callType': isVideoCall ? 'video' : 'audio',
        'status': duration > 0 ? 'ended' : 'missed',
        'duration': duration,
        'timestamp': DateTime.now().toIso8601String(),
        'callfrom': _storageService.getUserId(),
        'joined': duration > 0,
      });
    }
    _resetCallState();
  }

  Future<void> _setupPeerConnection({required bool video}) async {
    final configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _socketService.emitCallSignal({
        'signal': {
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        },
        'to': remoteUserId,
        'from': _storageService.getUserId(),
        'roomId': currentRoomId,
      });
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      remoteStream = stream;
      remoteRenderer.value.srcObject = stream;
      hasRemoteStream.value = true;
      remoteRenderer.refresh();
    };

    final mediaConstraints = {
      'audio': true,
      'video': video ? {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      } : false,
    };

    try {
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.value.srcObject = localStream;
      hasLocalStream.value = true;
      localRenderer.refresh();

      localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, localStream!);
      });
    } catch (e) {
      Get.log("Error getting user media: $e", isError: true);
    }
  }

  void toggleVideo() {
    if (localStream != null) {
      final videoTracks = localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final track = videoTracks.first;
        track.enabled = !track.enabled;
        isVideoEnabled.value = track.enabled;
      }
    }
  }

  void toggleAudio() {
    if (localStream != null) {
      final audioTracks = localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final track = audioTracks.first;
        track.enabled = !track.enabled;
        isAudioEnabled.value = track.enabled;
      }
    }
  }

  Future<void> toggleScreenShare() async {
    if (localStream == null || _peerConnection == null) return;

    if (!isScreenSharing.value) {
      try {
        final displayMedia = await navigator.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': false,
        });

        final videoTrack = displayMedia.getVideoTracks()[0];
        final senders = await _peerConnection!.getSenders();
        for (var sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(videoTrack);
          }
        }
        
        localRenderer.value.srcObject = displayMedia;
        localRenderer.refresh();
        isScreenSharing.value = true;
        
        // Listen to native stop screen sharing button (e.g. Android/Chrome notification)
        videoTrack.onEnded = () {
          toggleScreenShare(); // revert back to camera
        };
      } catch (e) {
        Get.log("Error sharing screen: $e", isError: true);
      }
    } else {
      // Revert to camera
      try {
        final cameraStream = await navigator.mediaDevices.getUserMedia({
          'video': {
            'facingMode': 'user',
          },
          'audio': false,
        });
        
        final videoTrack = cameraStream.getVideoTracks()[0];
        final senders = await _peerConnection!.getSenders();
        for (var sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(videoTrack);
          }
        }
        
        localRenderer.value.srcObject = localStream; // original audio/video stream
        localRenderer.refresh();
        isScreenSharing.value = false;
      } catch (e) {
        Get.log("Error stopping screen share: $e", isError: true);
      }
    }
  }

  void _resetCallState() {
    isCalling.value = false;
    isReceivingCall.value = false;
    isInCall.value = false;
    currentRoomId = null;
    remoteUserId = null;
    incomingCallData = null;
    callStartTime = null;
    isIncoming = false;
    isVideoCall = false;

    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;
    hasLocalStream.value = false;

    remoteStream?.getTracks().forEach((track) => track.stop());
    remoteStream?.dispose();
    remoteStream = null;
    hasRemoteStream.value = false;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;

    localRenderer.value.srcObject = null;
    remoteRenderer.value.srcObject = null;
  }

  @override
  void onClose() {
    _resetCallState();
    localRenderer.value.dispose();
    remoteRenderer.value.dispose();
    super.onClose();
  }
}
