import 'package:realm/realm.dart';

part 'realm_models.realm.dart';

@RealmModel()
class _UserRealm {
  @PrimaryKey()
  late String id;
  late String? userName;
  late String? email;
  late String? photo;
  late String? mobileNumber;
  late String? bio;
  late bool? isOnline;
  late DateTime? lastSeen;
}

@RealmModel()
class _MessageContentRealm {
  late String type; // "text", "file", "system", "call"
  late String? content;
  late String? fileUrl;
  late String? fileType;
  late String? size;
  late String? timestamp;
  late String? status;
  late String? callType;
  late String? duration;
  late String? callfrom;
  late String? joined;
}

@RealmModel()
class _MessageReactionRealm {
  late String emoji;
  late String userIdsJson;
}

@RealmModel()
class _MessageRealm {
  @PrimaryKey()
  late String id;
  late String senderId;
  late String receiverId;
  late _MessageContentRealm? content;
  late String status; // "sent", "delivered", "read", "deleted"
  late bool edited;
  late List<_MessageReactionRealm> reactions;
  late DateTime createdAt;
  late DateTime updatedAt;
  late bool isPending; // For offline queued messages
}

@RealmModel()
class _OfflineQueueRealm {
  @PrimaryKey()
  late String id;
  late String receiverId;
  late String type;
  late String content;
  late DateTime createdAt;
}

@RealmModel()
class _LocalContactRealm {
  @PrimaryKey()
  late String id; // Use phone number or system contact ID as primary key
  late String displayName;
  late String phoneNumber;
}
