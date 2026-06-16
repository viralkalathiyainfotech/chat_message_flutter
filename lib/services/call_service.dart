import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;
import 'package:uuid/uuid.dart';
import 'socket_service.dart';
import 'storage_service.dart';

class CallService extends GetxService {
  final SocketService _socketService = Get.find<SocketService>();
  final StorageService _storageService = Get.find<StorageService>();

  Map<String, RTCPeerConnection> peerConnections = {};
  MediaStream? localStream;

  // Reactive states
  final RxBool isCalling = false.obs;
  final RxBool isReceivingCall = false.obs;
  final RxBool isInCall = false.obs;
  final RxBool isVideoEnabled = true.obs;
  final RxBool isAudioEnabled = true.obs;
  final RxBool isScreenSharing = false.obs;

  final RxBool hasLocalStream = false.obs;
  final RxBool hasRemoteStream = false.obs; // True if ANY remote stream exists

  final Rx<RTCVideoRenderer> localRenderer = RTCVideoRenderer().obs;
  final RxMap<String, RTCVideoRenderer> remoteRenderers =
      <String, RTCVideoRenderer>{}.obs;
  final RxMap<String, MediaStream> remoteStreams = <String, MediaStream>{}.obs;

  String? currentRoomId;
  String? remoteUserId; // for 1-to-1, or groupId for group calls
  Map<String, dynamic>? incomingCallData;
  DateTime? callStartTime;
  bool isIncoming = false;
  bool isVideoCall = false;
  bool isGroupCall = false;
  Set<String> callParticipants = {}; // The current participants

  @override
  void onInit() {
    super.onInit();
    _setupSocketListeners();
    localRenderer.value.initialize();
  }

  void _setupSocketListeners() {
    _socketService.onIncomingCall = (data) {
      if (isInCall.value || isCalling.value) {
        // Already in a call, ignore
        return;
      }
      incomingCallData = data;
      remoteUserId = data['groupId'] ?? data['fromEmail'];
      currentRoomId = data['roomId'];
      isIncoming = true;
      isVideoCall = data['type'] == 'video';
      isGroupCall = data['isGroupCall'] == true;
      if (data['participants'] != null) {
        callParticipants = Set<String>.from(
          data['participants'].map((e) => e.toString()),
        );
      }
      isReceivingCall.value = true;
    };

    _socketService.onCallAccepted = (data) async {
      final signal = data['signal'];
      final fromEmail = data['fromEmail'];
      if (signal != null && peerConnections.containsKey(fromEmail)) {
        if (signal['type'] == 'answer') {
          await peerConnections[fromEmail]!.setRemoteDescription(
            RTCSessionDescription(signal['sdp'], signal['type']),
          );
        }
      }
      isCalling.value = false;
      isInCall.value = true;
      callStartTime ??= DateTime.now();
    };

    _socketService.onCallSignal = (data) async {
      final signal = data['signal'];
      final from = data['from'];
      if (signal != null && peerConnections.containsKey(from)) {
        final pc = peerConnections[from]!;
        if (signal['type'] == 'candidate' || signal['candidate'] != null) {
          final candidateMap = signal['candidate'] ?? signal;
          await pc.addCandidate(
            RTCIceCandidate(
              candidateMap['candidate'],
              candidateMap['sdpMid'],
              candidateMap['sdpMLineIndex'] ?? 0,
            ),
          );
        } else if (signal['type'] == 'offer' || signal['type'] == 'answer') {
          await pc.setRemoteDescription(
            RTCSessionDescription(signal['sdp'], signal['type']),
          );
        }
      }
    };

    // participant-joined (for Mesh topology)
    _socketService.socket?.on("participant-joined", (data) async {
      final newParticipantId = data['newParticipantId'];
      final roomId = data['roomId'];
      if (newParticipantId != _storageService.getUserId() &&
          roomId == currentRoomId) {
        callParticipants.add(newParticipantId);
        await _createPeerConnection(newParticipantId, isInitiator: true);
      }
    });

    _socketService.onEndCall = (data) {
      final from = data['from'];
      if (isGroupCall) {
        _removePeer(from);
        if (peerConnections.isEmpty) {
          endCallLocally();
        }
      } else {
        endCallLocally();
      }
    };

    _socketService.socket?.on("participant-lefted", (data) {
      final leavingUser = data['leavingUser'];
      if (leavingUser != null) {
        _removePeer(leavingUser);
        if (peerConnections.isEmpty) {
          endCallLocally();
        }
      }
    });

    _socketService.onUserInCall = (data) {
      if (!isGroupCall) {
        final message = data['message'] ?? 'User is currently in another call';
        Get.snackbar(
          'Call Failed',
          message,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        endCallLocally();
      }
    };
  }

  Future<bool> makeCall(
    String targetId, {
    bool video = true,
    bool isGroup = false,
    List<String>? participants,
  }) async {
    final connected = await _socketService.ensureConnected();
    if (!connected) {
      Get.snackbar(
        'Call Failed',
        'Unable to connect to call server. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    remoteUserId = targetId; // user ID or Group ID
    currentRoomId = const Uuid().v4();
    isCalling.value = true;
    isIncoming = false;
    isVideoCall = video;
    isGroupCall = isGroup;

    callParticipants = participants != null
        ? Set<String>.from(participants)
        : {_storageService.getUserId()!, targetId};

    await _initLocalStream(video: video);

    // In a Mesh, the caller creates an offer for every participant
    final otherMembers = callParticipants
        .where((id) => id != _storageService.getUserId())
        .toList();

    for (var memberId in otherMembers) {
      await _createPeerConnection(memberId, isInitiator: true);
    }

    return true;
  }

  Future<void> acceptCall() async {
    if (incomingCallData == null) return;

    final bool isVideo = incomingCallData!['type'] == 'video';
    await _initLocalStream(video: isVideo);

    isReceivingCall.value = false;
    isInCall.value = true;
    callStartTime = DateTime.now();

    final callerId = incomingCallData!['fromEmail'];
    final signal = incomingCallData!['signal'];

    // Connect to the caller
    await _createPeerConnection(callerId, isInitiator: false, offer: signal);

    // Connect to other existing participants (if group call)
    if (isGroupCall && incomingCallData!['participants'] != null) {
      final others = List<String>.from(
        incomingCallData!['participants'],
      ).where((id) => id != _storageService.getUserId() && id != callerId);
      for (var pId in others) {
        await _createPeerConnection(pId, isInitiator: true);
      }
    }
  }

  Future<void> _initLocalStream({required bool video}) async {
    final mediaConstraints = {
      'audio': true,
      'video': video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.value.srcObject = localStream;
      hasLocalStream.value = true;
      localRenderer.refresh();
    } catch (e) {
      Get.log("Error getting user media: $e", isError: true);
    }
  }

  Future<void> _createPeerConnection(
    String peerId, {
    required bool isInitiator,
    dynamic offer,
  }) async {
    if (peerConnections.containsKey(peerId)) return;

    final configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
    };

    final pc = await createPeerConnection(configuration);
    peerConnections[peerId] = pc;

    if (localStream != null) {
      localStream!.getTracks().forEach((track) {
        pc.addTrack(track, localStream!);
      });
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _socketService.emitCallSignal({
        'signal': {
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        },
        'to': peerId,
        'from': _storageService.getUserId(),
        'roomId': currentRoomId,
      });
    };

    pc.onAddStream = (MediaStream stream) async {
      remoteStreams[peerId] = stream;
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;
      remoteRenderers[peerId] = renderer;
      hasRemoteStream.value = true;
    };

    if (isInitiator) {
      final pcOffer = await pc.createOffer();
      await pc.setLocalDescription(pcOffer);

      _socketService.emitCallRequest({
        'fromEmail': _storageService.getUserId(),
        'toEmail': peerId,
        'signal': {'type': pcOffer.type, 'sdp': pcOffer.sdp},
        'type': isVideoCall ? 'video' : 'audio',
        'isGroupCall': isGroupCall,
        'participants': callParticipants.toList(),
        'groupId': isGroupCall ? remoteUserId : null,
        'roomId': currentRoomId,
      });
    } else if (offer != null) {
      if (offer['type'] == 'offer') {
        await pc.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        _socketService.emitCallAccept({
          'signal': {'type': answer.type, 'sdp': answer.sdp},
          'fromEmail': peerId,
          'toEmail': _storageService.getUserId(),
          'participants': callParticipants.toList(),
          'roomId': currentRoomId,
        });
      }
    }
  }

  void _removePeer(String peerId) {
    if (peerConnections.containsKey(peerId)) {
      peerConnections[peerId]?.close();
      peerConnections[peerId]?.dispose();
      peerConnections.remove(peerId);
    }
    if (remoteStreams.containsKey(peerId)) {
      remoteStreams[peerId]?.dispose();
      remoteStreams.remove(peerId);
    }
    if (remoteRenderers.containsKey(peerId)) {
      remoteRenderers[peerId]?.srcObject = null;
      remoteRenderers[peerId]?.dispose();
      remoteRenderers.remove(peerId);
    }
    callParticipants.remove(peerId);
    hasRemoteStream.value = remoteRenderers.isNotEmpty;
  }

  void declineCall() {
    _socketService.emitEndCall({
      'to': incomingCallData?['fromEmail'],
      'from': _storageService.getUserId(),
      'roomId': currentRoomId,
    });
    _resetCallState();
  }

  void endCall() {
    for (var peerId in peerConnections.keys) {
      _socketService.emitEndCall({
        'to': peerId,
        'from': _storageService.getUserId(),
        'roomId': currentRoomId,
      });
    }
    if (isGroupCall && callParticipants.length > 2) {
      _socketService.socket?.emit("participant-left", {
        "leavingUser": _storageService.getUserId(),
        "duration": callStartTime != null
            ? DateTime.now().difference(callStartTime!).inSeconds
            : 0,
        "roomId": currentRoomId,
      });
    }
    endCallLocally();
  }

  void endCallLocally() {
    if (!isIncoming && remoteUserId != null) {
      final duration = callStartTime != null
          ? DateTime.now().difference(callStartTime!).inSeconds
          : 0;
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
    // Screen sharing is more complex in a mesh network, simplified for now
    if (localStream == null || peerConnections.isEmpty) return;

    if (!isScreenSharing.value) {
      try {
        final displayMedia = await navigator.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': false,
        });

        final videoTrack = displayMedia.getVideoTracks()[0];

        for (var pc in peerConnections.values) {
          final senders = await pc.getSenders();
          for (var sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(videoTrack);
            }
          }
        }

        localRenderer.value.srcObject = displayMedia;
        localRenderer.refresh();
        isScreenSharing.value = true;

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
          'video': {'facingMode': 'user'},
          'audio': false,
        });

        final videoTrack = cameraStream.getVideoTracks()[0];
        for (var pc in peerConnections.values) {
          final senders = await pc.getSenders();
          for (var sender in senders) {
            if (sender.track?.kind == 'video') {
              await sender.replaceTrack(videoTrack);
            }
          }
        }

        localRenderer.value.srcObject = localStream;
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
    isGroupCall = false;
    callParticipants.clear();

    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;
    hasLocalStream.value = false;

    for (var stream in remoteStreams.values) {
      stream.getTracks().forEach((track) => track.stop());
      stream.dispose();
    }
    remoteStreams.clear();
    hasRemoteStream.value = false;

    for (var pc in peerConnections.values) {
      pc.close();
      pc.dispose();
    }
    peerConnections.clear();

    for (var renderer in remoteRenderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    remoteRenderers.clear();

    localRenderer.value.srcObject = null;
  }

  @override
  void onClose() {
    _resetCallState();
    localRenderer.value.dispose();
    super.onClose();
  }
}
