import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/network_constants.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

class SocketService extends GetxService {
  io.Socket? socket;
  final StorageService _storageService = Get.find<StorageService>();
  final RxBool isConnected = false.obs;

  // Callbacks for events
  Function(Map<String, dynamic>)? onReceiveMessage;
  Function(Map<String, dynamic>)? onMessageSentStatus;
  Function(Map<String, dynamic>)? onMessageRead;
  Function(Map<String, dynamic>)? onUserTyping;
  Function(Map<String, dynamic>)? onMessageUpdated;
  Function(dynamic)? onMessageDeleted; // Backend might send an ID or Map
  Function(Map<String, dynamic>)? onMessageReaction;
  Function(Map<String, dynamic>)? onRemoveMessageReaction;
  Function(List<String>)? onUserStatusChanged;
  
  final RxList<String> onlineUsers = <String>[].obs;

  // WebRTC Call Callbacks
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallAccepted;
  Function(Map<String, dynamic>)? onCallSignal;
  Function(Map<String, dynamic>)? onEndCall;
  Function(Map<String, dynamic>)? onUserInCall;

  @override
  void onInit() {
    super.onInit();
    _initSocket();
  }

  void connect() {
    if (socket == null) {
      _initSocket();
    } else if (!isConnected.value) {
      Get.log('==== MANUALLY CONNECTING SOCKET ====');
      socket?.connect();
    }
  }

  void disconnect() {
    socket?.disconnect();
  }

  Future<void> _initSocket() async {
    Get.log('==== INITIALIZING SOCKET ====');
    final token = _storageService.getToken();
    final userId = _storageService.getUserId();
    
    Get.log('==== SOCKET PARAMS: token exists? ${token != null}, userId: $userId ====');
    
    if (token == null || userId == null) {
      Get.log('==== CANNOT INIT SOCKET: Token or UserId missing ====');
      return;
    }

    // Ensure we have a deviceId for socket
    String? deviceId = _storageService.getString('deviceId');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _storageService.saveString('deviceId', deviceId);
    }

    final String baseUrl = NetworkConstants.baseUrl.replaceAll('/api', '');

    socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect() // Critical: Prevents race condition
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .setTimeout(20000)
          .setAuth({
            'token': token,
            'deviceId': deviceId,
            'deviceType': 'mobile',
          })
          .build(),
    );

    socket?.onAny((event, data) {
      Get.log('SOCKET EVENT => $event');
      Get.log('SOCKET DATA => $data');
    });

    socket?.onError((error) {
      Get.log('SOCKET ERROR => $error', isError: true);
    });

    socket?.onReconnect((attempt) {
      Get.log('RECONNECTED => $attempt');
    });

    socket?.onReconnectAttempt((attempt) {
      Get.log('RECONNECT ATTEMPT => $attempt');
    });

    socket?.onReconnectError((error) {
      Get.log('RECONNECT ERROR => $error', isError: true);
    });

    socket?.onReconnectFailed((_) {
      Get.log('RECONNECT FAILED', isError: true);
    });

    socket?.onPing((_) {
      Get.log('PING');
    });

    socket?.onPong((_) {
      Get.log('PONG');
    });

    socket?.onConnect((_) {
      Get.log('==== SOCKET CONNECTION ESTABLISHED SUCCESSFULLY ====');
      isConnected.value = true;
      socket?.emit('user-login', userId);
      socket?.emit('join-device-room', deviceId);
    });

    socket?.onConnectError((error) {
      Get.log('==== SOCKET CONNECTION ERROR: $error ====', isError: true);
      isConnected.value = false;
    });

    socket?.onDisconnect((_) {
      Get.log('==== SOCKET DISCONNECTED ====');
      isConnected.value = false;
    });

    // Listen to chat events
    socket?.on('receive-message', (data) {
      final map = _safeCast(data);
      if (map != null && onReceiveMessage != null) onReceiveMessage!(map);
    });

    socket?.on('message-sent-status', (data) {
      final map = _safeCast(data);
      if (map != null && onMessageSentStatus != null) onMessageSentStatus!(map);
    });

    socket?.on('message-read-update', (data) {
      final map = _safeCast(data);
      if (map != null && onMessageRead != null) onMessageRead!(map);
    });

    socket?.on('user-typing', (data) {
      final map = _safeCast(data);
      if (map != null && onUserTyping != null) onUserTyping!(map);
    });

    socket?.on('message-updated', (data) {
      final map = _safeCast(data);
      if (map != null && onMessageUpdated != null) onMessageUpdated!(map);
    });

    socket?.on('message-deleted', (data) {
      if (onMessageDeleted != null) {
        onMessageDeleted!(
          data is List && data.isNotEmpty ? data.first : data,
        ); // Could be a String ID
      }
    });

    socket?.on('message-reaction', (data) {
      final map = _safeCast(data);
      if (map != null && onMessageReaction != null) onMessageReaction!(map);
    });

    socket?.on('remove-message-reaction', (data) {
      final map = _safeCast(data);
      if (map != null && onRemoveMessageReaction != null) {
        onRemoveMessageReaction!(map);
      }
    });

    socket?.on('user-status-changed', (data) {
      final list = _safeCastList(data);
      if (list != null) {
        onlineUsers.value = list;
        if (onUserStatusChanged != null) {
          onUserStatusChanged!(list);
        }
      }
    });

    // WebRTC Listeners
    socket?.on('call-requested', (data) {
      final map = _safeCast(data);
      if (map != null && onIncomingCall != null) onIncomingCall!(map);
    });

    socket?.on('call-accepted', (data) {
      final map = _safeCast(data);
      if (map != null && onCallAccepted != null) onCallAccepted!(map);
    });

    socket?.on('call-signal', (data) {
      final map = _safeCast(data);
      if (map != null && onCallSignal != null) onCallSignal!(map);
    });

    socket?.on('call-ended', (data) {
      final map = _safeCast(data);
      if (map != null && onEndCall != null) onEndCall!(map);
    });

    socket?.on('user-in-call', (data) {
      final map = _safeCast(data);
      if (map != null && onUserInCall != null) onUserInCall!(map);
    });

    Get.log('==== LISTENERS ATTACHED, NOW CONNECTING... ====');
    socket?.connect();
  }

  void emitPrivateMessage(Map<String, dynamic> messageData) {
    if (isConnected.value) {
      socket?.emit('private-message', messageData);
    }
  }

  void emitTypingStatus(String receiverId, bool isTyping) {
    if (isConnected.value) {
      final userId = _storageService.getUserId();
      socket?.emit('typing-status', {
        'senderId': userId,
        'receiverId': receiverId,
        'isTyping': isTyping,
      });
    }
  }

  void emitMessageRead(String messageId) {
    if (isConnected.value) {
      final userId = _storageService.getUserId();
      socket?.emit('message-read', {
        'messageId': messageId,
        'readerId': userId,
      });
    }
  }

  void emitUpdateMessage(Map<String, dynamic> updateData) {
    if (isConnected.value) {
      socket?.emit('update-message', updateData);
    }
  }

  void emitDeleteMessage(String messageId) {
    if (isConnected.value) {
      socket?.emit('delete-message', messageId);
    }
  }

  void emitMessageReaction(Map<String, dynamic> reactionData) {
    if (isConnected.value) {
      socket?.emit('message-reaction', reactionData);
    }
  }

  void emitRemoveMessageReaction(Map<String, dynamic> reactionData) {
    if (isConnected.value) {
      socket?.emit('remove-message-reaction', reactionData);
    }
  }

  void getOnlineUsers() {
    if (isConnected.value) {
      final userId = _storageService.getUserId();
      if (userId != null) {
        socket?.emit('user-login', userId);
      }
    }
  }

  // Helper to safely cast payload to Map
  Map<String, dynamic>? _safeCast(dynamic data) {
    dynamic payload = data is List
        ? (data.isNotEmpty ? data.first : null)
        : data;
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  // Helper to safely cast payload to List of Strings
  List<String>? _safeCastList(dynamic data) {
    dynamic payload = data is List && data.isNotEmpty && data.first is List
        ? data.first
        : (data is List ? data : null);
        
    if (payload is List) {
      return payload.map((e) => e.toString()).toList();
    }
    return null;
  }

  @override
  void onClose() {
    socket?.disconnect();
    super.onClose();
  }

  // --- WebRTC Emits ---
  void emitCallRequest(Map<String, dynamic> data) {
    if (isConnected.value) {
      socket?.emit('call-request', data);
    }
  }

  void emitCallAccept(Map<String, dynamic> data) {
    if (isConnected.value) {
      socket?.emit('call-accept', data);
    }
  }

  void emitCallSignal(Map<String, dynamic> data) {
    if (isConnected.value) {
      socket?.emit('call-signal', data);
    }
  }

  void emitEndCall(Map<String, dynamic> data) {
    if (isConnected.value) {
      socket?.emit('end-call', data);
    }
  }

  void emitSaveCallMessage(Map<String, dynamic> data) {
    if (isConnected.value) {
      socket?.emit('save-call-message', data);
    }
  }
}
