import 'dart:convert';
import 'package:chat_app/core/network/api_service.dart';
import 'package:get/get.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../../core/database/realm_helper.dart';
import '../../../../../core/database/realm_models.dart';
import '../../../../../services/connectivity_service.dart';
import '../../../../../services/socket_service.dart';
import '../../../../../services/storage_service.dart';
import '../../../../../utils/encryption_util.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  final ApiService _apiService = Get.find<ApiService>();
  final RealmHelper _realmHelper = RealmHelper();
  final ConnectivityService _connectivity = Get.find<ConnectivityService>();
  final SocketService _socketService = Get.find<SocketService>();
  final _uuid = const Uuid();

  Future<List<UserRealm>> getChatList() async {
    // 1. Instantly return local cached chats
    final localChats = _realmHelper.getUsers();

    // 2. Fetch from network if online
    if (_connectivity.isOnline.value) {
      try {
        final response = await _apiService.dio.get('/allMessageUsers');
        if (response.statusCode == 200) {
          final usersData = response.data['users'] as List;
          final fetchedUsers = usersData.map((data) => UserRealm(
            data['_id'] ?? '',
            userName: data['userName'],
            email: data['email'],
            photo: data['photo'],
            mobileNumber: data['mobileNumber'],
            bio: data['bio'],
            isOnline: data['isOnline'], // Map from socket info if available later
          )).toList();

          _realmHelper.saveUsers(fetchedUsers);
          return fetchedUsers;
        }
      } catch (e) {
        Get.log('Error fetching chat list: $e', isError: true);
      }
    }

    return localChats;
  }

  Future<List<UserRealm>> searchUsers(String query) async {
    // This simulates an API search by fetching all users and filtering locally,
    // since the backend doesn't currently expose a dedicated /search endpoint.
    final users = await getUserList();
    if (query.isEmpty) return users;
    
    final lowerQuery = query.toLowerCase();
    return users.where((u) => 
      (u.userName ?? '').toLowerCase().contains(lowerQuery) ||
      (u.email ?? '').toLowerCase().contains(lowerQuery) ||
      (u.mobileNumber ?? '').contains(lowerQuery)
    ).toList();
  }

  Future<List<MessageRealm>> getMessages(String userId, {bool fetchFromNetwork = true}) async {
    final localMessages = _realmHelper.getMessagesForUser(userId);

    if (fetchFromNetwork && _connectivity.isOnline.value) {
      try {
        final response = await _apiService.dio.post('/allMessages', data: {'selectedId': userId});
        if (response.statusCode == 200) {
          final messagesData = response.data['messages'] as List;
          final fetchedMessages = messagesData.map((data) {
            final contentData = data['content'];
            final contentRealm = MessageContentRealm(
              contentData['type'] ?? 'text',
              content: contentData['content'],
              fileUrl: contentData['fileUrl'],
              fileType: contentData['fileType']?.toString(),
              size: contentData['size']?.toString(),
              timestamp: contentData['timestamp']?.toString(),
              status: contentData['status']?.toString(),
            );

            List<MessageReactionRealm> parsedReactions = [];
            if (data['reactions'] != null && data['reactions'] is List) {
              parsedReactions = (data['reactions'] as List).map((r) {
                return MessageReactionRealm(
                  r['emoji']?.toString() ?? '',
                  jsonEncode([r['userId']?.toString() ?? '']), // Backend sends userId for each reaction
                );
              }).toList();
            }

            return MessageRealm(
              data['_id'] ?? '',
              data['sender'] ?? '',
              data['receiver'] ?? '',
              data['status'] ?? 'sent',
              data['edited'] ?? false,
              DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
              DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
              false,
              content: contentRealm,
              reactions: parsedReactions,
            );
          }).toList();

          _realmHelper.saveMessages(fetchedMessages);
          return _realmHelper.getMessagesForUser(userId);
        }
      } catch (e) {
        Get.log('Error fetching messages: $e', isError: true);
      }
    }

    return localMessages;
  }

  Future<void> saveIncomingMessage(Map<String, dynamic> data) async {
    try {
      final contentData = data['content'] ?? {};
      final contentRealm = MessageContentRealm(
        contentData['type'] ?? 'text',
        content: contentData['content'],
        fileUrl: contentData['fileUrl'],
        fileType: contentData['fileType']?.toString(),
        size: contentData['size']?.toString(),
        timestamp: contentData['timestamp']?.toString(),
        status: contentData['status']?.toString(),
      );

      List<MessageReactionRealm> parsedReactions = [];
      if (data['reactions'] != null && data['reactions'] is List) {
        parsedReactions = (data['reactions'] as List).map((r) {
          return MessageReactionRealm(
            r['emoji']?.toString() ?? '',
            jsonEncode([r['userId']?.toString() ?? '']),
          );
        }).toList();
      }

      final newMsg = MessageRealm(
        data['_id'] ?? data['messageId'] ?? _uuid.v4(),
        data['sender'] ?? data['senderId'] ?? '',
        data['receiver'] ?? data['receiverId'] ?? '',
        data['status'] ?? 'delivered',
        data['edited'] ?? false,
        DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
        DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
        false,
        content: contentRealm,
        reactions: parsedReactions,
      );

      _realmHelper.saveMessage(newMsg);
    } catch (e) {
      Get.log('Error saving incoming message: $e', isError: true);
    }
  }

  Future<void> sendMessage(String receiverId, String content, String type) async {
    final tempId = _uuid.v4();
    final now = DateTime.now();

    final userId = Get.find<StorageService>().getUserId() ?? 'myUserId';
    
    // Encrypt the content if it's text
    String finalContent = content;
    if (type == 'text') {
      finalContent = EncryptionUtil.encrypt(content);
    }
    
    // Save locally first
    final contentRealm = MessageContentRealm(type, content: finalContent);
    final localMessage = MessageRealm(
      tempId,
      userId,
      receiverId,
      'sent',
      false,
      now,
      now,
      true, // isPending
      content: contentRealm,
    );
    _realmHelper.saveMessage(localMessage);

    if (_connectivity.isOnline.value) {
      // Send directly
      await _sendRealtimeMessage(receiverId, finalContent, type, tempId);
    } else {
      // Add to offline queue
      final queuedMsg = OfflineQueueRealm(
        tempId,
        receiverId,
        type,
        finalContent,
        now,
      );
      _realmHelper.addToQueue(queuedMsg);
    }
  }

  Future<void> _sendRealtimeMessage(String receiverId, String content, String type, String tempId) async {
    // Logic to send message through socket
    Get.log('Sending message to $receiverId');
    final userId = Get.find<StorageService>().getUserId() ?? 'myUserId';
    _socketService.emitPrivateMessage({
      'senderId': userId,
      'receiverId': receiverId,
      'content': {
        'type': type,
        'content': content,
      },
      'replyTo': null,
      'isBlocked': false,
      'tempMessageId': tempId,
    });
  }

  void updateMessageStatusLocally(String messageId, String status) {
    _realmHelper.updateMessageStatus(messageId, status);
  }

  void updateMessageContentLocally(String messageId, String newContent) {
    _realmHelper.updateMessageContent(messageId, newContent);
  }

  void handleMessageReactionLocally(String messageId, String userId, String emoji, String action) {
    _realmHelper.handleMessageReactionLocally(messageId, userId, emoji, action);
  }

  void replaceTempMessageIdLocally(String tempId, String newId, String status) {
    _realmHelper.replaceTempMessageId(tempId, newId, status);
  }

  Future<void> deleteMessage(String messageId) async {
    _realmHelper.deleteMessage(messageId);
    if (_connectivity.isOnline.value) {
      _socketService.emitDeleteMessage(messageId);
    }
  }

  Future<void> editMessage(String messageId, String newContent, String type) async {
    String finalContent = newContent;
    if (type == 'text') {
      finalContent = EncryptionUtil.encrypt(newContent);
    }
    
    _realmHelper.updateMessageContent(messageId, finalContent);

    if (_connectivity.isOnline.value) {
      _socketService.emitUpdateMessage({
        'messageId': messageId,
        'content': {
          'type': type,
          'content': finalContent,
        }
      });
    }
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    if (_connectivity.isOnline.value) {
      final userId = Get.find<StorageService>().getUserId();
      _socketService.emitMessageReaction({
        'messageId': messageId,
        'emoji': emoji,
        'userId': userId,
      });
    }
  }
  
  Future<void> removeReaction(String messageId) async {
    if (_connectivity.isOnline.value) {
      final userId = Get.find<StorageService>().getUserId();
      _socketService.emitRemoveMessageReaction({
        'messageId': messageId,
        'userId': userId,
      });
    }
  }

  Future<List<UserRealm>> getUserList() async {
    // 1. Instantly return local cached contacts
    final localContacts = _realmHelper.getUsers();

    // 2. Fetch from network if online
    if (_connectivity.isOnline.value) {
      try {
        final response = await _apiService.dio.get('/allContactUsers');
        if (response.statusCode == 200) {
          final usersData = response.data['users'] as List;
          final fetchedUsers = usersData.map((data) {
            // Filter out local Android content:// URIs that won't load over network
            final rawPhoto = data['photo'] as String?;
            final photo = (rawPhoto != null && rawPhoto.startsWith('http')) ? rawPhoto : null;
            return UserRealm(
              data['_id'] ?? '',
              userName: data['userName'],
              email: data['email'],
              photo: photo,
              mobileNumber: data['mobileNumber'],
              bio: data['bio'],
              isOnline: null, // Populated by socket events, not API
            );
          }).toList();

          _realmHelper.saveUsers(fetchedUsers);
          return fetchedUsers;
        }
      } catch (e) {
        Get.log('Error fetching contact users: $e', isError: true);
      }
    }

    return localContacts;
  }

  Future<List<LocalContactRealm>> syncContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      Get.log('Contacts permission denied');
      return _realmHelper.getLocalContacts();
    }

    final deviceContacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
    final cachedContacts = _realmHelper.getLocalContacts();
    
    // Create map for easy comparison
    final cachedMap = {for (var c in cachedContacts) c.phoneNumber: c.displayName};
    
    bool hasChanges = false;
    List<LocalContactRealm> newLocalContacts = [];
    List<Map<String, dynamic>> apiContactsPayload = [];

    for (var dc in deviceContacts) {
      if (dc.phones.isNotEmpty) {
        final rawPhone = dc.phones.first.number;
        final formattedPhone = rawPhone.replaceAll(RegExp(r'\s+|-|\(|\)'), ''); // Basic normalization
        final displayName = dc.displayName;
        
        newLocalContacts.add(LocalContactRealm(dc.id ?? '', displayName ?? '', formattedPhone));
        
        apiContactsPayload.add({
          "id": dc.id,
          "name": displayName,
          "phone": formattedPhone,
        });

        if (cachedMap[formattedPhone] != displayName) {
          hasChanges = true;
        }
      }
    }

    if (cachedContacts.length != newLocalContacts.length) {
      hasChanges = true;
    }

    if (hasChanges) {
      Get.log('Contacts changed. Syncing with backend...');
      _realmHelper.clearLocalContacts();
      _realmHelper.saveLocalContacts(newLocalContacts);
      
      if (_connectivity.isOnline.value) {
        try {
          await _apiService.dio.post('/addContactList', data: [
            {
              "contacts": apiContactsPayload
            }
          ]);
          Get.log('Contacts synced successfully');
        } catch (e) {
          Get.log('Error syncing contacts to API: $e', isError: true);
        }
      }
    } else {
      Get.log('No changes in contacts. Skip API sync.');
    }

    return newLocalContacts;
  }
}
