import 'dart:convert';
import 'package:realm/realm.dart';
import 'realm_models.dart';

class RealmHelper {
  static final RealmHelper _instance = RealmHelper._internal();
  factory RealmHelper() => _instance;
  RealmHelper._internal();

  late Realm _realm;

  void init() {
    final config = Configuration.local([
      UserRealm.schema,
      MessageContentRealm.schema,
      MessageRealm.schema,
      MessageReactionRealm.schema,
      OfflineQueueRealm.schema,
      LocalContactRealm.schema,
    ], schemaVersion: 4);
    _realm = Realm(config);
  }

  Realm get realm => _realm;

  // --- Users ---
  void saveUsers(List<UserRealm> users) {
    _realm.write(() {
      for (var user in users) {
        _realm.add(user, update: true);
      }
    });
  }

  List<UserRealm> getUsers() {
    return _realm.all<UserRealm>().toList();
  }

  // --- Messages ---
  void saveMessages(List<MessageRealm> messages) {
    _realm.write(() {
      for (var msg in messages) {
        _realm.add(msg, update: true);
      }
    });
  }

  void saveMessage(MessageRealm msg) {
    _realm.write(() {
      _realm.add(msg, update: true);
    });
  }

  void updateMessageStatus(String messageId, String status) {
    _realm.write(() {
      final msg = _realm.find<MessageRealm>(messageId);
      if (msg != null) {
        msg.status = status;
      }
    });
  }

  void replaceTempMessageId(String tempId, String newId, String status) {
    _realm.write(() {
      final oldMsg = _realm.find<MessageRealm>(tempId);
      if (oldMsg != null) {
        final newMsg = MessageRealm(
          newId,
          oldMsg.senderId,
          oldMsg.receiverId,
          status,
          oldMsg.edited,
          oldMsg.createdAt,
          oldMsg.updatedAt,
          false,
          content: oldMsg.content != null ? MessageContentRealm(
            oldMsg.content!.type,
            content: oldMsg.content!.content,
            fileUrl: oldMsg.content!.fileUrl,
            fileType: oldMsg.content!.fileType,
            size: oldMsg.content!.size,
            timestamp: oldMsg.content!.timestamp,
            status: oldMsg.content!.status,
          ) : null,
          reactions: oldMsg.reactions.map((r) => MessageReactionRealm(r.emoji, r.userIdsJson)).toList(),
        );
        _realm.delete(oldMsg);
        _realm.add(newMsg, update: true);
      }
    });
  }

  void deleteMessage(String messageId) {
    _realm.write(() {
      final msg = _realm.find<MessageRealm>(messageId);
      if (msg != null) {
        _realm.delete(msg);
      }
    });
  }

  void updateMessageContent(String messageId, String newContent) {
    _realm.write(() {
      final msg = _realm.find<MessageRealm>(messageId);
      if (msg != null && msg.content != null) {
        msg.content!.content = newContent;
        msg.edited = true;
      }
    });
  }

  void updateMessageReactions(String messageId, List<MessageReactionRealm> reactions) {
    _realm.write(() {
      final msg = _realm.find<MessageRealm>(messageId);
      if (msg != null) {
        msg.reactions.clear();
        msg.reactions.addAll(reactions);
      }
    });
  }

  void handleMessageReactionLocally(String messageId, String userId, String emoji, String action) {
    _realm.write(() {
      final msg = _realm.find<MessageRealm>(messageId);
      if (msg != null) {
        // Find existing reaction for this emoji
        int existingIndex = -1;
        for (int i = 0; i < msg.reactions.length; i++) {
          if (msg.reactions[i].emoji == emoji) {
            existingIndex = i;
            break;
          }
        }

        if (action == 'added') {
          if (existingIndex != -1) {
            // Check if user is already in JSON
            List<dynamic> users = jsonDecode(msg.reactions[existingIndex].userIdsJson);
            if (!users.contains(userId)) {
              users.add(userId);
              msg.reactions[existingIndex].userIdsJson = jsonEncode(users);
            }
          } else {
            msg.reactions.add(MessageReactionRealm(emoji, jsonEncode([userId])));
          }
        } else if (action == 'removed') {
          if (existingIndex != -1) {
            List<dynamic> users = jsonDecode(msg.reactions[existingIndex].userIdsJson);
            users.remove(userId);
            if (users.isEmpty) {
              msg.reactions.removeAt(existingIndex);
            } else {
              msg.reactions[existingIndex].userIdsJson = jsonEncode(users);
            }
          }
        }
      }
    });
  }

  List<MessageRealm> getMessagesForUser(String userId) {
    return _realm.query<MessageRealm>('senderId == \$0 OR receiverId == \$0 SORT(createdAt ASC)', [userId]).toList();
  }

  MessageRealm? getLastMessageForUser(String userId) {
    final messages = _realm.query<MessageRealm>('senderId == \$0 OR receiverId == \$0 SORT(createdAt DESC)', [userId]);
    return messages.isNotEmpty ? messages.first : null;
  }

  List<MessageRealm> getPendingMessages() {
    return _realm.query<MessageRealm>('isPending == true').toList();
  }

  // --- Offline Queue ---
  void addToQueue(OfflineQueueRealm queuedMsg) {
    _realm.write(() {
      _realm.add(queuedMsg);
    });
  }

  List<OfflineQueueRealm> getQueue() {
    return _realm.all<OfflineQueueRealm>().toList();
  }

  void removeFromQueue(String id) {
    _realm.write(() {
      final msg = _realm.find<OfflineQueueRealm>(id);
      if (msg != null) {
        _realm.delete(msg);
      }
    });
  }

  void clearQueue() {
    _realm.write(() {
      _realm.deleteAll<OfflineQueueRealm>();
    });
  }

  // --- Local Contacts ---
  void saveLocalContacts(List<LocalContactRealm> contacts) {
    _realm.write(() {
      for (var contact in contacts) {
        _realm.add(contact, update: true);
      }
    });
  }

  List<LocalContactRealm> getLocalContacts() {
    return _realm.all<LocalContactRealm>().toList();
  }

  void clearLocalContacts() {
    _realm.write(() {
      _realm.deleteAll<LocalContactRealm>();
    });
  }
}
