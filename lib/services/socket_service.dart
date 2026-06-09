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

  @override
  void onInit() {
    super.onInit();
    _initSocket();
  }

  Future<void> _initSocket() async {
    final token = _storageService.getToken();
    final userId = _storageService.getUserId();
    if (token == null || userId == null) {
      Get.log('Cannot init socket: Token or UserId missing', isError: true);
      return;
    }

    // Ensure we have a deviceId for socket
    String? deviceId = _storageService.getString('deviceId');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _storageService.saveString('deviceId', deviceId);
    }

    final String baseUrl = NetworkConstants.baseUrl.replaceAll('/api', '');

    socket = io.io(baseUrl, io.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .setReconnectionAttempts(5)
      .setReconnectionDelay(1000)
      .setTimeout(20000)
      .setAuth({
        'token': token,
        'deviceId': deviceId,
        'deviceType': 'mobile',
      })
      .build());

    socket?.onConnect((_) {
      Get.log('Socket connection established');
      isConnected.value = true;
      socket?.emit('user-login', userId);
      socket?.emit('join-device-room', deviceId);
    });

    socket?.onConnectError((error) {
      Get.log('Socket connection error: $error', isError: true);
      isConnected.value = false;
    });

    socket?.onDisconnect((_) {
      Get.log('Socket disconnected');
      isConnected.value = false;
    });

    // Listen to chat events
    socket?.on('receive-message', (data) {
      if (onReceiveMessage != null) onReceiveMessage!(data);
    });

    socket?.on('message-sent-status', (data) {
      if (onMessageSentStatus != null) onMessageSentStatus!(data);
    });

    socket?.on('message-read', (data) {
      if (onMessageRead != null) onMessageRead!(data);
    });

    socket?.on('user-typing', (data) {
      if (onUserTyping != null) onUserTyping!(data);
    });
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

  @override
  void onClose() {
    socket?.disconnect();
    super.onClose();
  }
}
