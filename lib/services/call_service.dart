import 'dart:convert';

import 'package:chat_app/core/database/realm_helper.dart';
import 'package:chat_app/core/database/realm_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;
import 'package:uuid/uuid.dart';
import 'socket_service.dart';
import 'storage_service.dart';

class CallService extends GetxService {
  static const MethodChannel _notificationChannel = MethodChannel(
    'app.call/notification',
  );

  final SocketService _socketService = Get.find<SocketService>();
  final StorageService _storageService = Get.find<StorageService>();

  Map<String, RTCPeerConnection> peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _pendingRemoteCandidates = {};
  MediaStream? localStream;
  MediaStream? _screenShareStream;
  MediaStreamTrack? _cameraVideoTrackBeforeScreenShare;
  bool _isStoppingScreenShare = false;

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
  final RxList<CallAudioOutput> audioOutputs = <CallAudioOutput>[].obs;
  final RxString selectedAudioOutputId = CallAudioOutput.speakerId.obs;

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
        callParticipants = _normalizeParticipantIds(data['participants']);
      }
      if (isGroupCall && remoteUserId != null) {
        callParticipants.addAll(_memberIdsFromGroup(remoteUserId!));
      }
      final currentUserId = _storageService.getUserId();
      if (currentUserId != null) callParticipants.add(currentUserId);
      isReceivingCall.value = true;
    };

    _socketService.onCallAccepted = (data) async {
      final signal = data['signal'];
      final peerId = _peerIdFromPayload(data);
      if (signal != null &&
          peerId != null &&
          peerConnections.containsKey(peerId)) {
        if (signal['type'] == 'answer') {
          final didApplyAnswer = await _applyRemoteDescription(peerId, signal);
          if (didApplyAnswer) {
            _markCallConnected();
          }
        }
      } else {
        Get.log('Unable to apply call answer from payload: $data');
      }
    };

    _socketService.onCallSignal = (data) async {
      final signal = data['signal'];
      final peerId = _peerIdFromPayload(data);
      if (signal == null || peerId == null) return;

      if (signal['type'] == 'offer' && !peerConnections.containsKey(peerId)) {
        await _createPeerConnection(peerId, isInitiator: false, offer: signal);
        isInCall.value = true;
        callStartTime ??= DateTime.now();
        return;
      }

      final pc = peerConnections[peerId];
      if (pc == null) {
        final candidate = _candidateFromSignal(signal);
        if (candidate != null) {
          _pendingRemoteCandidates.putIfAbsent(peerId, () => []).add(candidate);
        }
        return;
      }

      final candidate = _candidateFromSignal(signal);
      if (candidate != null) {
        await _addOrBufferRemoteCandidate(peerId, pc, candidate);
      } else if (signal['type'] == 'offer' || signal['type'] == 'answer') {
        final didApplyDescription = await _applyRemoteDescription(
          peerId,
          signal,
        );
        if (didApplyDescription && signal['type'] == 'answer') {
          _markCallConnected();
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

    final currentUserId = _storageService.getUserId()!;
    callParticipants = _participantsForCall(
      targetId: targetId,
      isGroup: isGroup,
      participants: participants,
      currentUserId: currentUserId,
    );

    await _initLocalStream(video: video);

    // In a Mesh, the caller creates an offer for every participant
    final otherMembers = callParticipants
        .where((id) => id != currentUserId && (!isGroupCall || id != targetId))
        .toList();

    for (var memberId in otherMembers) {
      await _createPeerConnection(memberId, isInitiator: true);
    }

    return true;
  }

  Set<String> _participantsForCall({
    required String targetId,
    required bool isGroup,
    required List<String>? participants,
    required String currentUserId,
  }) {
    final ids = <String>{currentUserId};

    if (isGroup) {
      ids.addAll(_normalizeParticipantIds(participants));
      ids.addAll(_memberIdsFromGroup(targetId));
    } else {
      ids.add(targetId);
    }

    if (isGroup && ids.length <= 1) {
      Get.snackbar(
        'Group call',
        'No group members found for this call.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    return ids;
  }

  Set<String> _memberIdsFromGroup(String groupId) {
    final group = RealmHelper().realm.find<UserRealm>(groupId);
    if (group?.membersListJson == null) return {};

    try {
      final decoded = jsonDecode(group!.membersListJson!);
      if (decoded is! List) return {};
      return _normalizeParticipantIds(decoded);
    } catch (e) {
      Get.log('Error decoding group call members: $e', isError: true);
      return {};
    }
  }

  Set<String> _normalizeParticipantIds(Iterable<dynamic>? participants) {
    if (participants == null) return {};
    return participants
        .map((participant) {
          if (participant is Map) {
            return (participant['_id'] ?? participant['id'])?.toString();
          }
          return participant?.toString();
        })
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
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
      final others = _normalizeParticipantIds(
        incomingCallData!['participants'],
      ).where((id) => id != _storageService.getUserId() && id != callerId);
      for (var pId in others) {
        await _createPeerConnection(
          pId,
          isInitiator: true,
          sendOfferAsCallSignal: true,
        );
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
      await selectPreferredAudioOutput();
    } catch (e) {
      Get.log("Error getting user media: $e", isError: true);
    }
  }

  Future<void> refreshAudioOutputs() async {
    try {
      final devices = await Helper.audiooutputs;
      final outputs = <CallAudioOutput>[];

      for (final device in devices) {
        final output = CallAudioOutput.fromMediaDevice(device);
        if (output == null || output.isBuiltIn) continue;
        if (outputs.any((item) => item.id == output.id)) continue;
        outputs.add(output);
      }

      if (!isVideoCall) {
        outputs.add(CallAudioOutput.earpiece);
      }
      outputs.add(CallAudioOutput.mainSpeaker);

      audioOutputs.assignAll(outputs);
      if (!outputs.any((output) => output.id == selectedAudioOutputId.value)) {
        selectedAudioOutputId.value = _preferredAudioOutputId(outputs);
      }
    } catch (e) {
      Get.log('Unable to refresh audio outputs: $e', isError: true);
      final fallbackOutputs = isVideoCall
          ? const [CallAudioOutput.mainSpeaker]
          : const [CallAudioOutput.earpiece, CallAudioOutput.mainSpeaker];
      audioOutputs.assignAll(fallbackOutputs);
      selectedAudioOutputId.value = _preferredAudioOutputId(fallbackOutputs);
    }
  }

  Future<void> selectPreferredAudioOutput() async {
    await refreshAudioOutputs();
    await selectAudioOutput(_preferredAudioOutputId(audioOutputs));
  }

  Future<void> selectAudioOutput(String outputId) async {
    try {
      if (outputId == CallAudioOutput.secondarySpeakerId) {
        await Helper.selectAudioOutput(CallAudioOutput.secondarySpeakerId);
      } else if (outputId == CallAudioOutput.speakerId) {
        await Helper.setSpeakerphoneOn(true);
      } else {
        await Helper.selectAudioOutput(outputId);
      }
      if (outputId != CallAudioOutput.secondarySpeakerId &&
          outputId != CallAudioOutput.speakerId) {
        for (final renderer in remoteRenderers.values) {
          await renderer.audioOutput(outputId);
        }
        await localRenderer.value.audioOutput(outputId);
      }
      selectedAudioOutputId.value = outputId;
    } catch (e) {
      Get.log('Unable to select audio output $outputId: $e', isError: true);
    }
  }

  String _preferredAudioOutputId(Iterable<CallAudioOutput> outputs) {
    for (final output in outputs) {
      if (!output.isBuiltIn) return output.id;
    }

    if (!isVideoCall &&
        outputs.any(
          (output) => output.id == CallAudioOutput.secondarySpeakerId,
        )) {
      return CallAudioOutput.secondarySpeakerId;
    }

    return CallAudioOutput.speakerId;
  }

  Future<void> _createPeerConnection(
    String peerId, {
    required bool isInitiator,
    dynamic offer,
    bool sendOfferAsCallSignal = false,
  }) async {
    if (peerConnections.containsKey(peerId)) return;

    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    final pc = await createPeerConnection(configuration);
    peerConnections[peerId] = pc;

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await pc.addTrack(track, localStream!);
      }
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

    pc.onTrack = (RTCTrackEvent event) async {
      Get.log(
        'Remote track from $peerId: '
        'kind=${event.track.kind}, streams=${event.streams.length}',
      );

      if (event.track.kind != 'video') return;

      final stream = _videoStreamFromTrackEvent(event);
      if (stream != null) {
        await _attachRemoteStream(peerId, stream);
        return;
      }

      final fallbackStream = await createLocalMediaStream(
        'remote-video-$peerId-${event.track.id ?? DateTime.now().microsecondsSinceEpoch}',
      );
      await fallbackStream.addTrack(event.track);
      await _attachRemoteStream(peerId, fallbackStream);
    };

    pc.onAddStream = (MediaStream stream) async {
      await _attachRemoteStream(peerId, stream);
    };

    if (isInitiator) {
      final pcOffer = await pc.createOffer();
      await pc.setLocalDescription(pcOffer);

      final offerSignal = {'type': pcOffer.type, 'sdp': pcOffer.sdp};
      if (sendOfferAsCallSignal) {
        _socketService.emitCallSignal({
          'signal': offerSignal,
          'from': _storageService.getUserId(),
          'to': peerId,
          'roomId': currentRoomId,
        });
      } else {
        _socketService.emitCallRequest({
          'fromEmail': _storageService.getUserId(),
          'toEmail': peerId,
          'signal': offerSignal,
          'type': isVideoCall ? 'video' : 'audio',
          'isGroupCall': isGroupCall,
          'participants': callParticipants.toList(),
          'groupId': isGroupCall ? remoteUserId : null,
          'roomId': currentRoomId,
        });
      }
    } else if (offer != null) {
      if (offer['type'] == 'offer') {
        final didApplyOffer = await _applyRemoteDescription(peerId, offer);
        if (!didApplyOffer) return;
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        _socketService.emitCallAccept({
          'signal': {'type': answer.type, 'sdp': answer.sdp},
          'fromEmail': peerId,
          'toEmail': _storageService.getUserId(),
          'participants': callParticipants.toList(),
          'roomId': currentRoomId,
        });

        _socketService.emitCallSignal({
          'signal': {'type': answer.type, 'sdp': answer.sdp},
          'from': _storageService.getUserId(),
          'to': peerId,
          'roomId': currentRoomId,
        });
      }
    }
  }

  void _markCallConnected() {
    isCalling.value = false;
    isReceivingCall.value = false;
    isInCall.value = true;
    callStartTime ??= DateTime.now();
  }

  Future<bool> _applyRemoteDescription(
    String peerId,
    Map<dynamic, dynamic> signal,
  ) async {
    final pc = peerConnections[peerId];
    if (pc == null) return false;

    final type = signal['type']?.toString();
    final sdp = signal['sdp']?.toString();
    if (type == null || sdp == null || sdp.isEmpty) return false;

    final state = await pc.getSignalingState();
    if (type == 'answer' &&
        state != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      Get.log('Skipping remote answer for $peerId in signaling state $state');
      return false;
    }

    if (type == 'offer' && state != RTCSignalingState.RTCSignalingStateStable) {
      Get.log('Skipping remote offer for $peerId in signaling state $state');
      return false;
    }

    try {
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      await _flushPendingRemoteCandidates(peerId);
      return true;
    } catch (e) {
      Get.log('Unable to apply remote $type for $peerId: $e', isError: true);
      return false;
    }
  }

  String? _peerIdFromPayload(Map<String, dynamic> data) {
    final myId = _storageService.getUserId();
    final candidates = [
      data['from'],
      data['fromEmail'],
      data['senderId'],
      data['userId'],
      data['to'],
      data['toEmail'],
      data['receiverId'],
    ];

    for (final candidate in candidates) {
      final id = candidate?.toString();
      if (id != null && id.isNotEmpty && id != myId) return id;
    }
    return null;
  }

  MediaStream? _videoStreamFromTrackEvent(RTCTrackEvent event) {
    for (final stream in event.streams) {
      if (stream.getVideoTracks().isNotEmpty) return stream;
    }
    return null;
  }

  RTCIceCandidate? _candidateFromSignal(dynamic signal) {
    if (signal is! Map) return null;
    if (signal['type'] != 'candidate' && signal['candidate'] == null) {
      return null;
    }

    final candidateMap = signal['candidate'] is Map
        ? signal['candidate'] as Map
        : signal;
    final candidate = candidateMap['candidate']?.toString();
    if (candidate == null || candidate.isEmpty) return null;

    final sdpMLineIndexValue = candidateMap['sdpMLineIndex'];
    final sdpMLineIndex = sdpMLineIndexValue is int
        ? sdpMLineIndexValue
        : int.tryParse(sdpMLineIndexValue?.toString() ?? '') ?? 0;

    return RTCIceCandidate(
      candidate,
      candidateMap['sdpMid']?.toString(),
      sdpMLineIndex,
    );
  }

  Future<void> _addOrBufferRemoteCandidate(
    String peerId,
    RTCPeerConnection pc,
    RTCIceCandidate candidate,
  ) async {
    try {
      await pc.addCandidate(candidate);
    } catch (e) {
      _pendingRemoteCandidates.putIfAbsent(peerId, () => []).add(candidate);
      Get.log('Buffered ICE candidate for $peerId: $e');
    }
  }

  Future<void> _flushPendingRemoteCandidates(String peerId) async {
    final pc = peerConnections[peerId];
    final candidates = _pendingRemoteCandidates.remove(peerId);
    if (pc == null || candidates == null) return;

    for (final candidate in candidates) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        Get.log('Unable to add buffered ICE candidate for $peerId: $e');
      }
    }
  }

  Future<void> _attachRemoteStream(String peerId, MediaStream stream) async {
    final videoTrackCount = stream.getVideoTracks().length;
    final audioTrackCount = stream.getAudioTracks().length;
    if (videoTrackCount == 0) {
      Get.log(
        'Ignoring remote stream for $peerId without video tracks '
        '(audio: $audioTrackCount)',
      );
      return;
    }

    remoteStreams[peerId] = stream;

    final existingRenderer = remoteRenderers[peerId];
    if (existingRenderer != null) {
      existingRenderer.srcObject = stream;
      remoteRenderers.refresh();
    } else {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;
      await renderer.audioOutput(selectedAudioOutputId.value);
      remoteRenderers[peerId] = renderer;
    }

    hasRemoteStream.value = true;
    Get.log(
      'Remote stream attached for $peerId '
      '(video: $videoTrackCount, '
      'audio: $audioTrackCount)',
    );
  }

  void _removePeer(String peerId) {
    _pendingRemoteCandidates.remove(peerId);
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
    if (localStream == null || peerConnections.isEmpty) return;

    if (!isScreenSharing.value) {
      await _startScreenShare();
    } else {
      await _stopScreenShare();
    }
  }

  Future<void> _startScreenShare() async {
    MediaStream? displayMedia;
    try {
      final cameraTracks = localStream!.getVideoTracks();
      if (cameraTracks.isEmpty) {
        Get.log('Cannot start screen share without an active video track');
        return;
      }

      _cameraVideoTrackBeforeScreenShare = cameraTracks.first;
      await _setScreenShareForegroundState(true);
      displayMedia = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });

      final displayTracks = displayMedia.getVideoTracks();
      if (displayTracks.isEmpty) {
        await _disposeMediaStream(displayMedia);
        await _setScreenShareForegroundState(false);
        Get.log('Screen share did not return a video track', isError: true);
        return;
      }

      final screenTrack = displayTracks.first;
      _screenShareStream = displayMedia;
      await _replaceOutgoingVideoTrack(screenTrack);

      localRenderer.value.srcObject = displayMedia;
      localRenderer.refresh();
      isScreenSharing.value = true;

      screenTrack.onEnded = () {
        if (!_isStoppingScreenShare && isScreenSharing.value) {
          _stopScreenShare();
        }
      };
    } catch (e) {
      await _disposeMediaStream(_screenShareStream ?? displayMedia);
      _screenShareStream = null;
      _cameraVideoTrackBeforeScreenShare = null;
      isScreenSharing.value = false;
      localRenderer.value.srcObject = localStream;
      localRenderer.refresh();
      await _setScreenShareForegroundState(false);
      Get.log("Error sharing screen: $e", isError: true);
    }
  }

  Future<void> _stopScreenShare() async {
    if (_isStoppingScreenShare) return;
    _isStoppingScreenShare = true;

    try {
      final cameraTrack =
          _cameraVideoTrackBeforeScreenShare ??
          (localStream!.getVideoTracks().isNotEmpty
              ? localStream!.getVideoTracks().first
              : null);

      if (cameraTrack != null) {
        await _replaceOutgoingVideoTrack(cameraTrack);
      }

      await _disposeMediaStream(_screenShareStream);
      _screenShareStream = null;
      _cameraVideoTrackBeforeScreenShare = null;

      localRenderer.value.srcObject = localStream;
      localRenderer.refresh();
      isScreenSharing.value = false;
      await _setScreenShareForegroundState(false);
    } catch (e) {
      Get.log("Error stopping screen share: $e", isError: true);
    } finally {
      _isStoppingScreenShare = false;
    }
  }

  Future<void> _replaceOutgoingVideoTrack(MediaStreamTrack videoTrack) async {
    for (final pc in peerConnections.values) {
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(videoTrack);
        }
      }
    }
  }

  Future<void> _disposeMediaStream(MediaStream? stream) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  Future<void> _setScreenShareForegroundState(bool active) async {
    if (!isInCall.value) return;

    try {
      final typeLabel = isVideoCall ? 'Video call' : 'Voice call';
      final remoteName = remoteUserId ?? 'Active call';
      await _notificationChannel.invokeMethod<void>('showOngoingCall', {
        'title': typeLabel,
        'body': '$remoteName • ongoing',
        'isVideo': isVideoCall,
        'audioEnabled': isAudioEnabled.value,
        'videoEnabled': isVideoEnabled.value,
        'isScreenSharing': active,
      });
      if (active) {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      }
    } on PlatformException catch (e) {
      Get.log(
        'Unable to update screen share foreground service: ${e.message}',
        isError: true,
      );
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
    audioOutputs.clear();
    selectedAudioOutputId.value = CallAudioOutput.speakerId;

    localStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    localStream = null;
    _screenShareStream?.getTracks().forEach((track) => track.stop());
    _screenShareStream?.dispose();
    _screenShareStream = null;
    _cameraVideoTrackBeforeScreenShare = null;
    _isStoppingScreenShare = false;
    isScreenSharing.value = false;
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
    _pendingRemoteCandidates.clear();

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

class CallAudioOutput {
  const CallAudioOutput({
    required this.id,
    required this.label,
    required this.icon,
    this.isBuiltIn = false,
  });

  static const secondarySpeakerId = 'earpiece';
  static const speakerId = 'speaker';

  static const earpiece = CallAudioOutput(
    id: secondarySpeakerId,
    label: 'Earpiece',
    icon: Icons.phone_in_talk,
    isBuiltIn: true,
  );

  static const mainSpeaker = CallAudioOutput(
    id: speakerId,
    label: 'Main speaker',
    icon: Icons.volume_up,
    isBuiltIn: true,
  );

  final String id;
  final String label;
  final IconData icon;
  final bool isBuiltIn;

  static CallAudioOutput? fromMediaDevice(MediaDeviceInfo device) {
    final id = device.deviceId;
    final normalizedId = id.toLowerCase();
    final normalizedLabel = device.label.toLowerCase();

    if (normalizedId == 'earpiece' || normalizedLabel.contains('earpiece')) {
      return earpiece;
    }

    if (normalizedId == 'speaker' || normalizedLabel.contains('speaker')) {
      return mainSpeaker;
    }

    if (normalizedId == 'bluetooth' || normalizedLabel.contains('bluetooth')) {
      return CallAudioOutput(
        id: id,
        label: device.label.isEmpty ? 'Bluetooth' : device.label,
        icon: Icons.bluetooth_audio,
      );
    }

    if (normalizedId == 'wired-headset' ||
        normalizedLabel.contains('wired') ||
        normalizedLabel.contains('headset') ||
        normalizedLabel.contains('headphone')) {
      return CallAudioOutput(
        id: id,
        label: device.label.isEmpty ? 'Wired headset' : device.label,
        icon: Icons.headphones,
      );
    }

    return null;
  }
}
