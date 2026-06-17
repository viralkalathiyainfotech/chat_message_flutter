import 'dart:convert';
import 'dart:io';
import 'package:chat_app/constants/network_constants.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:dio/dio.dart' as dio;
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

  String _formatFileSize(int sizeBytes) {
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<List<UserRealm>> getChatList({bool fetchFromNetwork = true}) async {
    // 1. Instantly return local cached chats
    final localChats = _realmHelper.getUsers();

    // 2. Fetch from network if online
    if (fetchFromNetwork && _connectivity.isOnline.value) {
      try {
        final response = await _apiService.dio.get(
          NetworkConstants.allMessageUsers,
        );
        if (response.statusCode == 200) {
          final usersData = response.data['users'] as List;
          final List<MessageRealm> allMessagesToSave = [];

          final fetchedUsers = usersData.map((data) {
            if (data['messages'] != null && data['messages'] is List) {
              final msgs = (data['messages'] as List).map((msgData) {
                final contentData = msgData['content'] ?? {};
                final contentRealm = MessageContentRealm(
                  contentData['type'] ?? 'text',
                  content: contentData['content'],
                  fileUrl: contentData['fileUrl'],
                  fileType: contentData['fileType']?.toString(),
                  size: contentData['size']?.toString(),
                  timestamp: contentData['timestamp']?.toString(),
                  status: contentData['status']?.toString(),
                  callType: contentData['callType']?.toString(),
                  duration: contentData['duration']?.toString(),
                  callfrom: contentData['callfrom']?.toString(),
                  joined: contentData['joined']?.toString(),
                );

                List<MessageReactionRealm> parsedReactions = [];
                if (msgData['reactions'] != null &&
                    msgData['reactions'] is List) {
                  parsedReactions = (msgData['reactions'] as List).map((r) {
                    return MessageReactionRealm(
                      r['emoji']?.toString() ?? '',
                      jsonEncode([r['userId']?.toString() ?? '']),
                    );
                  }).toList();
                }

                return MessageRealm(
                  msgData['_id']?.toString() ?? '',
                  _idFromPayload(msgData['senderId'] ?? msgData['sender']),
                  _idFromPayload(
                    msgData['groupId'] ??
                        msgData['group'] ??
                        msgData['receiverId'] ??
                        msgData['receiver'],
                  ),
                  msgData['status']?.toString() ?? 'sent',
                  msgData['edited'] == true,
                  DateTime.tryParse(msgData['createdAt']?.toString() ?? '') ??
                      DateTime.now(),
                  DateTime.tryParse(msgData['updatedAt']?.toString() ?? '') ??
                      DateTime.now(),
                  false,
                  content: contentRealm,
                  reactions: parsedReactions,
                );
              }).toList();
              allMessagesToSave.addAll(msgs);
            }

            return UserRealm(
              data['_id']?.toString() ?? '',
              userName: data['userName']?.toString(),
              email: data['email']?.toString(),
              photo: data['photo']?.toString(),
              mobileNumber: data['mobileNumber']?.toString(),
              bio: data['bio']?.toString(),
              isOnline: data['isOnline'] == true,
              isGroup: data['isGroup'] == true,
              membersListJson: data['members'] != null
                  ? jsonEncode(data['members'])
                  : null,
            );
          }).toList();

          try {
            final groupResponse = await _apiService.dio.get(
              NetworkConstants.allGroups,
            );
            if (groupResponse.statusCode == 200) {
              final groupsData = groupResponse.data as List;
              final fetchedGroups = groupsData.map((data) {
                return UserRealm(
                  data['_id']?.toString() ?? '',
                  userName: data['userName']?.toString() ?? 'Group',
                  photo: data['photo']?.toString(),
                  bio: data['bio']?.toString(),
                  isGroup: true,
                  membersListJson: jsonEncode(data['members']),
                );
              }).toList();
              fetchedUsers.addAll(fetchedGroups);
            }
          } catch (e) {
            Get.log('Error fetching groups: $e', isError: true);
          }

          try {
            final callsResponse = await _apiService.dio.get(
              NetworkConstants.allCallUsers,
            );
            if (callsResponse.statusCode == 200) {
              final callsData = callsResponse.data['users'] as List;
              final fetchedCallUsers = callsData.map((data) {
                // Return UserRealm, and also save their latest call message
                if (data['messages'] != null &&
                    (data['messages'] as List).isNotEmpty) {
                  for (var msgData in (data['messages'] as List)) {
                    saveIncomingMessage(msgData);
                  }
                }
                return UserRealm(
                  data['_id']?.toString() ?? '',
                  userName: data['userName']?.toString(),
                  email: data['email']?.toString(),
                  photo: data['photo']?.toString(),
                );
              }).toList();
              fetchedUsers.addAll(fetchedCallUsers);
            }
          } catch (e) {
            Get.log('Error fetching call users: $e', isError: true);
          }

          // Deduplicate fetchedUsers by ID before saving
          final uniqueUsers = <String, UserRealm>{};
          for (var user in fetchedUsers) {
            // Let the one with more fields take precedence
            if (!uniqueUsers.containsKey(user.id) || (user.isGroup == true)) {
              uniqueUsers[user.id] = user;
            } else {
              if (user.photo != null) uniqueUsers[user.id]!.photo = user.photo;
              if (user.userName != null) {
                uniqueUsers[user.id]!.userName = user.userName;
              }
              if (user.email != null) uniqueUsers[user.id]!.email = user.email;
              if (user.mobileNumber != null) {
                uniqueUsers[user.id]!.mobileNumber = user.mobileNumber;
              }
              if (user.bio != null) uniqueUsers[user.id]!.bio = user.bio;
            }
          }

          Get.log('Total unique users: \${uniqueUsers.length}');
          Get.log(
            'Total groups: \${uniqueUsers.values.where((u) => u.isGroup == true).length}',
          );

          _realmHelper.saveUsers(uniqueUsers.values.toList());
          if (allMessagesToSave.isNotEmpty) {
            _realmHelper.saveMessages(allMessagesToSave);
          }
          return _realmHelper.getUsers();
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
    return users
        .where(
          (u) =>
              (u.userName ?? '').toLowerCase().contains(lowerQuery) ||
              (u.email ?? '').toLowerCase().contains(lowerQuery) ||
              (u.mobileNumber ?? '').contains(lowerQuery),
        )
        .toList();
  }

  Future<List<MessageRealm>> getMessages(
    String userId, {
    bool fetchFromNetwork = true,
  }) async {
    final localMessages = _realmHelper.getMessagesForUser(userId);

    if (fetchFromNetwork && _connectivity.isOnline.value) {
      try {
        final response = await _apiService.dio.post(
          NetworkConstants.allMessages,
          data: {'selectedId': userId},
        );
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
              callType: contentData['callType']?.toString(),
              duration: contentData['duration']?.toString(),
              callfrom: contentData['callfrom']?.toString(),
              joined: contentData['joined']?.toString(),
            );

            List<MessageReactionRealm> parsedReactions = [];
            if (data['reactions'] != null && data['reactions'] is List) {
              parsedReactions = (data['reactions'] as List).map((r) {
                return MessageReactionRealm(
                  r['emoji']?.toString() ?? '',
                  jsonEncode([
                    r['userId']?.toString() ?? '',
                  ]), // Backend sends userId for each reaction
                );
              }).toList();
            }

            return MessageRealm(
              data['_id']?.toString() ?? '',
              _idFromPayload(data['senderId'] ?? data['sender']),
              _idFromPayload(
                data['groupId'] ??
                    data['group'] ??
                    data['receiverId'] ??
                    data['receiver'],
              ),
              data['status']?.toString() ?? 'sent',
              data['edited'] == true,
              DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
                  DateTime.now(),
              DateTime.tryParse(data['updatedAt']?.toString() ?? '') ??
                  DateTime.now(),
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
      final senderRaw = data['senderId'] ?? data['sender'];
      final receiverRaw = data['receiverId'] ?? data['receiver'];
      final groupRaw = data['groupId'] ?? data['group'];
      final senderId = _idFromPayload(senderRaw);
      final receiverId = _idFromPayload(receiverRaw);
      final groupId = _idFromPayload(groupRaw);
      final myId = Get.find<StorageService>().getUserId();

      if (senderId.isEmpty || (receiverId.isEmpty && groupId.isEmpty)) {
        Get.log(
          'Skipping incoming message with missing sender/receiver: $data',
        );
        return;
      }

      final isGroupMessage =
          groupId.isNotEmpty || (receiverId.isNotEmpty && receiverId != myId);
      final chatId = isGroupMessage
          ? (groupId.isNotEmpty ? groupId : receiverId)
          : senderId;
      _ensureChatUser(
        chatId,
        source: groupRaw ?? (isGroupMessage ? receiverRaw : senderRaw),
        isGroup: isGroupMessage,
      );

      if (senderId != myId) {
        _ensureChatUser(senderId, source: senderRaw, isGroup: false);
      }

      final contentRealm = MessageContentRealm(
        contentData['type'] ?? 'text',
        content: contentData['content'],
        fileUrl: contentData['fileUrl'],
        fileType: contentData['fileType']?.toString(),
        size: contentData['size']?.toString(),
        timestamp: contentData['timestamp']?.toString(),
        status: contentData['status']?.toString(),
        callType: contentData['callType']?.toString(),
        duration: contentData['duration']?.toString(),
        callfrom: contentData['callfrom']?.toString(),
        joined: contentData['joined']?.toString(),
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
        data['_id']?.toString() ?? data['messageId']?.toString() ?? _uuid.v4(),
        senderId,
        isGroupMessage ? chatId : receiverId,
        data['status']?.toString() ?? (senderId == myId ? 'sent' : 'delivered'),
        data['edited'] ?? false,
        DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        DateTime.tryParse(data['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
        false,
        content: contentRealm,
        reactions: parsedReactions,
      );

      _realmHelper.saveMessage(newMsg);
    } catch (e) {
      Get.log('Error saving incoming message: $e', isError: true);
    }
  }

  String _idFromPayload(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return (value['_id'] ?? value['id'] ?? '').toString();
    }
    return value.toString();
  }

  void _ensureChatUser(
    String userId, {
    required dynamic source,
    required bool isGroup,
  }) {
    final existing = _realmHelper.realm.find<UserRealm>(userId);
    final sourceMap = source is Map ? source : const {};

    String? stringField(String key) {
      final value = sourceMap[key];
      if (value == null) return null;
      final text = value.toString();
      return text.isEmpty ? null : text;
    }

    if (existing == null) {
      _realmHelper.saveUsers([
        UserRealm(
          userId,
          userName:
              stringField('userName') ??
              stringField('name') ??
              stringField('email') ??
              (isGroup ? 'Group' : 'Unknown'),
          email: stringField('email'),
          photo: stringField('photo'),
          mobileNumber: stringField('mobileNumber'),
          isGroup: isGroup,
          membersListJson: sourceMap['members'] != null
              ? jsonEncode(sourceMap['members'])
              : null,
        ),
      ]);
      return;
    }

    _realmHelper.realm.write(() {
      existing.userName ??=
          stringField('userName') ??
          stringField('name') ??
          stringField('email');
      existing.email ??= stringField('email');
      existing.photo ??= stringField('photo');
      existing.mobileNumber ??= stringField('mobileNumber');
      if (isGroup) {
        existing.isGroup = true;
      } else {
        existing.isGroup ??= false;
      }
      if (existing.membersListJson == null && sourceMap['members'] != null) {
        existing.membersListJson = jsonEncode(sourceMap['members']);
      }
    });
  }

  Future<Map<String, String>> uploadAttachment({
    required String path,
    required String fileName,
    required int sizeBytes,
  }) async {
    if (!_connectivity.isOnline.value) {
      throw Exception('Attachment upload requires an internet connection.');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Selected file could not be found.');
    }

    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(path, filename: fileName),
    });

    final response = await _apiService.dio.post(
      NetworkConstants.upload,
      data: formData,
    );
    if (response.statusCode != 200 ||
        response.data == null ||
        response.data['fileUrl'] == null) {
      throw Exception('Upload failed.');
    }

    return {
      'content': fileName,
      'fileUrl': response.data['fileUrl'].toString(),
      'fileType':
          response.data['fileType']?.toString() ?? 'application/octet-stream',
      'size': _formatFileSize(sizeBytes),
    };
  }

  Future<void> sendMessage(
    String receiverId,
    String content,
    String type, {
    String? fileUrl,
    String? fileType,
    String? size,
  }) async {
    final tempId = _uuid.v4();
    final now = DateTime.now();

    final userId = Get.find<StorageService>().getUserId() ?? 'myUserId';
    final isGroupMessage =
        _realmHelper.realm.find<UserRealm>(receiverId)?.isGroup == true;

    // Encrypt the content if it's text
    String finalContent = content;
    if (type == 'text') {
      finalContent = EncryptionUtil.encrypt(content);
    }

    // Save locally first
    final contentRealm = MessageContentRealm(
      type,
      content: finalContent,
      fileUrl: fileUrl,
      fileType: fileType,
      size: size,
    );
    final localMessage = MessageRealm(
      tempId,
      userId,
      receiverId,
      'sent',
      false,
      now,
      now,
      !_connectivity.isOnline.value || !isGroupMessage,
      content: contentRealm,
    );
    _realmHelper.saveMessage(localMessage);

    if (_connectivity.isOnline.value) {
      // Send directly
      await sendRealtimeMessage(
        receiverId,
        finalContent,
        type,
        tempId,
        fileUrl: fileUrl,
        fileType: fileType,
        size: size,
      );
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

  Future<void> sendRealtimeMessage(
    String receiverId,
    String content,
    String type,
    String tempId, {
    String? fileUrl,
    String? fileType,
    String? size,
  }) async {
    // Logic to send message through socket
    Get.log('Sending message to $receiverId');
    final userId = Get.find<StorageService>().getUserId() ?? 'myUserId';
    final isGroupMessage =
        _realmHelper.realm.find<UserRealm>(receiverId)?.isGroup == true;
    final contentData = {
      'type': type,
      'content': content,
      'fileUrl': ?fileUrl,
      'fileType': ?fileType,
      'size': ?size,
    };

    if (isGroupMessage) {
      _socketService.emitGroupMessage({
        'senderId': userId,
        'groupId': receiverId,
        'content': contentData,
      });
      return;
    }

    _socketService.emitPrivateMessage({
      'senderId': userId,
      'receiverId': receiverId,
      'content': contentData,
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

  void handleMessageReactionLocally(
    String messageId,
    String userId,
    String emoji,
    String action,
  ) {
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

  Future<void> editMessage(
    String messageId,
    String newContent,
    String type,
  ) async {
    String finalContent = newContent;
    if (type == 'text') {
      finalContent = EncryptionUtil.encrypt(newContent);
    }

    _realmHelper.updateMessageContent(messageId, finalContent);

    if (_connectivity.isOnline.value) {
      try {
        await _apiService.dio.put(
          NetworkConstants.updateMessage(messageId),
          data: {
            'content': {'type': type, 'content': finalContent},
          },
        );
      } catch (e) {
        Get.log('Error updating message on server: $e', isError: true);
      }

      _socketService.emitUpdateMessage({
        'messageId': messageId,
        'content': {'type': type, 'content': finalContent},
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
        final response = await _apiService.dio.get(
          NetworkConstants.allContactUsers,
        );
        if (response.statusCode == 200) {
          final usersData = response.data['users'] as List;
          final fetchedUsers = usersData.map((data) {
            // Filter out local Android content:// URIs that won't load over network
            final rawPhoto = data['photo'] as String?;
            final photo = (rawPhoto != null && rawPhoto.startsWith('http'))
                ? rawPhoto
                : null;
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

    final deviceContacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final cachedContacts = _realmHelper.getLocalContacts();

    // Create map for easy comparison
    final cachedMap = {
      for (var c in cachedContacts) c.phoneNumber: c.displayName,
    };

    bool hasChanges = false;
    List<LocalContactRealm> newLocalContacts = [];
    List<Map<String, dynamic>> apiContactsPayload = [];

    for (var dc in deviceContacts) {
      if (dc.phones.isNotEmpty) {
        final rawPhone = dc.phones.first.number;
        final formattedPhone = rawPhone.replaceAll(
          RegExp(r'\s+|-|\(|\)'),
          '',
        ); // Basic normalization
        final displayName = dc.displayName;

        newLocalContacts.add(
          LocalContactRealm(dc.id ?? '', displayName ?? '', formattedPhone),
        );

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
          await _apiService.dio.post(
            NetworkConstants.addContactList,
            data: [
              {"contacts": apiContactsPayload},
            ],
          );
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
