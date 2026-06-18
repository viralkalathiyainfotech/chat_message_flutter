// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realm_models.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
class UserRealm extends _UserRealm
    with RealmEntity, RealmObjectBase, RealmObject {
  UserRealm(
    String id, {
    String? userName,
    String? email,
    String? photo,
    String? mobileNumber,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isGroup,
    String? membersListJson,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'userName', userName);
    RealmObjectBase.set(this, 'email', email);
    RealmObjectBase.set(this, 'photo', photo);
    RealmObjectBase.set(this, 'mobileNumber', mobileNumber);
    RealmObjectBase.set(this, 'bio', bio);
    RealmObjectBase.set(this, 'isOnline', isOnline);
    RealmObjectBase.set(this, 'lastSeen', lastSeen);
    RealmObjectBase.set(this, 'isGroup', isGroup);
    RealmObjectBase.set(this, 'membersListJson', membersListJson);
  }

  UserRealm._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String? get userName =>
      RealmObjectBase.get<String>(this, 'userName') as String?;
  @override
  set userName(String? value) => RealmObjectBase.set(this, 'userName', value);

  @override
  String? get email => RealmObjectBase.get<String>(this, 'email') as String?;
  @override
  set email(String? value) => RealmObjectBase.set(this, 'email', value);

  @override
  String? get photo => RealmObjectBase.get<String>(this, 'photo') as String?;
  @override
  set photo(String? value) => RealmObjectBase.set(this, 'photo', value);

  @override
  String? get mobileNumber =>
      RealmObjectBase.get<String>(this, 'mobileNumber') as String?;
  @override
  set mobileNumber(String? value) =>
      RealmObjectBase.set(this, 'mobileNumber', value);

  @override
  String? get bio => RealmObjectBase.get<String>(this, 'bio') as String?;
  @override
  set bio(String? value) => RealmObjectBase.set(this, 'bio', value);

  @override
  bool? get isOnline => RealmObjectBase.get<bool>(this, 'isOnline') as bool?;
  @override
  set isOnline(bool? value) => RealmObjectBase.set(this, 'isOnline', value);

  @override
  DateTime? get lastSeen =>
      RealmObjectBase.get<DateTime>(this, 'lastSeen') as DateTime?;
  @override
  set lastSeen(DateTime? value) => RealmObjectBase.set(this, 'lastSeen', value);

  @override
  bool? get isGroup => RealmObjectBase.get<bool>(this, 'isGroup') as bool?;
  @override
  set isGroup(bool? value) => RealmObjectBase.set(this, 'isGroup', value);

  @override
  String? get membersListJson =>
      RealmObjectBase.get<String>(this, 'membersListJson') as String?;
  @override
  set membersListJson(String? value) =>
      RealmObjectBase.set(this, 'membersListJson', value);

  @override
  Stream<RealmObjectChanges<UserRealm>> get changes =>
      RealmObjectBase.getChanges<UserRealm>(this);

  @override
  Stream<RealmObjectChanges<UserRealm>> changesFor([List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<UserRealm>(this, keyPaths);

  @override
  UserRealm freeze() => RealmObjectBase.freezeObject<UserRealm>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'userName': userName.toEJson(),
      'email': email.toEJson(),
      'photo': photo.toEJson(),
      'mobileNumber': mobileNumber.toEJson(),
      'bio': bio.toEJson(),
      'isOnline': isOnline.toEJson(),
      'lastSeen': lastSeen.toEJson(),
      'isGroup': isGroup.toEJson(),
      'membersListJson': membersListJson.toEJson(),
    };
  }

  static EJsonValue _toEJson(UserRealm value) => value.toEJson();
  static UserRealm _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'id': EJsonValue id} => UserRealm(
        fromEJson(id),
        userName: fromEJson(ejson['userName']),
        email: fromEJson(ejson['email']),
        photo: fromEJson(ejson['photo']),
        mobileNumber: fromEJson(ejson['mobileNumber']),
        bio: fromEJson(ejson['bio']),
        isOnline: fromEJson(ejson['isOnline']),
        lastSeen: fromEJson(ejson['lastSeen']),
        isGroup: fromEJson(ejson['isGroup']),
        membersListJson: fromEJson(ejson['membersListJson']),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(UserRealm._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(ObjectType.realmObject, UserRealm, 'UserRealm', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('userName', RealmPropertyType.string, optional: true),
      SchemaProperty('email', RealmPropertyType.string, optional: true),
      SchemaProperty('photo', RealmPropertyType.string, optional: true),
      SchemaProperty('mobileNumber', RealmPropertyType.string, optional: true),
      SchemaProperty('bio', RealmPropertyType.string, optional: true),
      SchemaProperty('isOnline', RealmPropertyType.bool, optional: true),
      SchemaProperty('lastSeen', RealmPropertyType.timestamp, optional: true),
      SchemaProperty('isGroup', RealmPropertyType.bool, optional: true),
      SchemaProperty(
        'membersListJson',
        RealmPropertyType.string,
        optional: true,
      ),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class MessageContentRealm extends _MessageContentRealm
    with RealmEntity, RealmObjectBase, RealmObject {
  MessageContentRealm(
    String type, {
    String? content,
    String? fileUrl,
    String? fileType,
    String? size,
    String? timestamp,
    String? status,
    String? callType,
    String? duration,
    String? callfrom,
    String? joined,
  }) {
    RealmObjectBase.set(this, 'type', type);
    RealmObjectBase.set(this, 'content', content);
    RealmObjectBase.set(this, 'fileUrl', fileUrl);
    RealmObjectBase.set(this, 'fileType', fileType);
    RealmObjectBase.set(this, 'size', size);
    RealmObjectBase.set(this, 'timestamp', timestamp);
    RealmObjectBase.set(this, 'status', status);
    RealmObjectBase.set(this, 'callType', callType);
    RealmObjectBase.set(this, 'duration', duration);
    RealmObjectBase.set(this, 'callfrom', callfrom);
    RealmObjectBase.set(this, 'joined', joined);
  }

  MessageContentRealm._();

  @override
  String get type => RealmObjectBase.get<String>(this, 'type') as String;
  @override
  set type(String value) => RealmObjectBase.set(this, 'type', value);

  @override
  String? get content =>
      RealmObjectBase.get<String>(this, 'content') as String?;
  @override
  set content(String? value) => RealmObjectBase.set(this, 'content', value);

  @override
  String? get fileUrl =>
      RealmObjectBase.get<String>(this, 'fileUrl') as String?;
  @override
  set fileUrl(String? value) => RealmObjectBase.set(this, 'fileUrl', value);

  @override
  String? get fileType =>
      RealmObjectBase.get<String>(this, 'fileType') as String?;
  @override
  set fileType(String? value) => RealmObjectBase.set(this, 'fileType', value);

  @override
  String? get size => RealmObjectBase.get<String>(this, 'size') as String?;
  @override
  set size(String? value) => RealmObjectBase.set(this, 'size', value);

  @override
  String? get timestamp =>
      RealmObjectBase.get<String>(this, 'timestamp') as String?;
  @override
  set timestamp(String? value) => RealmObjectBase.set(this, 'timestamp', value);

  @override
  String? get status => RealmObjectBase.get<String>(this, 'status') as String?;
  @override
  set status(String? value) => RealmObjectBase.set(this, 'status', value);

  @override
  String? get callType =>
      RealmObjectBase.get<String>(this, 'callType') as String?;
  @override
  set callType(String? value) => RealmObjectBase.set(this, 'callType', value);

  @override
  String? get duration =>
      RealmObjectBase.get<String>(this, 'duration') as String?;
  @override
  set duration(String? value) => RealmObjectBase.set(this, 'duration', value);

  @override
  String? get callfrom =>
      RealmObjectBase.get<String>(this, 'callfrom') as String?;
  @override
  set callfrom(String? value) => RealmObjectBase.set(this, 'callfrom', value);

  @override
  String? get joined => RealmObjectBase.get<String>(this, 'joined') as String?;
  @override
  set joined(String? value) => RealmObjectBase.set(this, 'joined', value);

  @override
  Stream<RealmObjectChanges<MessageContentRealm>> get changes =>
      RealmObjectBase.getChanges<MessageContentRealm>(this);

  @override
  Stream<RealmObjectChanges<MessageContentRealm>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<MessageContentRealm>(this, keyPaths);

  @override
  MessageContentRealm freeze() =>
      RealmObjectBase.freezeObject<MessageContentRealm>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'type': type.toEJson(),
      'content': content.toEJson(),
      'fileUrl': fileUrl.toEJson(),
      'fileType': fileType.toEJson(),
      'size': size.toEJson(),
      'timestamp': timestamp.toEJson(),
      'status': status.toEJson(),
      'callType': callType.toEJson(),
      'duration': duration.toEJson(),
      'callfrom': callfrom.toEJson(),
      'joined': joined.toEJson(),
    };
  }

  static EJsonValue _toEJson(MessageContentRealm value) => value.toEJson();
  static MessageContentRealm _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'type': EJsonValue type} => MessageContentRealm(
        fromEJson(type),
        content: fromEJson(ejson['content']),
        fileUrl: fromEJson(ejson['fileUrl']),
        fileType: fromEJson(ejson['fileType']),
        size: fromEJson(ejson['size']),
        timestamp: fromEJson(ejson['timestamp']),
        status: fromEJson(ejson['status']),
        callType: fromEJson(ejson['callType']),
        duration: fromEJson(ejson['duration']),
        callfrom: fromEJson(ejson['callfrom']),
        joined: fromEJson(ejson['joined']),
      ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(MessageContentRealm._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      MessageContentRealm,
      'MessageContentRealm',
      [
        SchemaProperty('type', RealmPropertyType.string),
        SchemaProperty('content', RealmPropertyType.string, optional: true),
        SchemaProperty('fileUrl', RealmPropertyType.string, optional: true),
        SchemaProperty('fileType', RealmPropertyType.string, optional: true),
        SchemaProperty('size', RealmPropertyType.string, optional: true),
        SchemaProperty('timestamp', RealmPropertyType.string, optional: true),
        SchemaProperty('status', RealmPropertyType.string, optional: true),
        SchemaProperty('callType', RealmPropertyType.string, optional: true),
        SchemaProperty('duration', RealmPropertyType.string, optional: true),
        SchemaProperty('callfrom', RealmPropertyType.string, optional: true),
        SchemaProperty('joined', RealmPropertyType.string, optional: true),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class MessageReactionRealm extends _MessageReactionRealm
    with RealmEntity, RealmObjectBase, RealmObject {
  MessageReactionRealm(String emoji, String userIdsJson) {
    RealmObjectBase.set(this, 'emoji', emoji);
    RealmObjectBase.set(this, 'userIdsJson', userIdsJson);
  }

  MessageReactionRealm._();

  @override
  String get emoji => RealmObjectBase.get<String>(this, 'emoji') as String;
  @override
  set emoji(String value) => RealmObjectBase.set(this, 'emoji', value);

  @override
  String get userIdsJson =>
      RealmObjectBase.get<String>(this, 'userIdsJson') as String;
  @override
  set userIdsJson(String value) =>
      RealmObjectBase.set(this, 'userIdsJson', value);

  @override
  Stream<RealmObjectChanges<MessageReactionRealm>> get changes =>
      RealmObjectBase.getChanges<MessageReactionRealm>(this);

  @override
  Stream<RealmObjectChanges<MessageReactionRealm>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<MessageReactionRealm>(this, keyPaths);

  @override
  MessageReactionRealm freeze() =>
      RealmObjectBase.freezeObject<MessageReactionRealm>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'emoji': emoji.toEJson(),
      'userIdsJson': userIdsJson.toEJson(),
    };
  }

  static EJsonValue _toEJson(MessageReactionRealm value) => value.toEJson();
  static MessageReactionRealm _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {'emoji': EJsonValue emoji, 'userIdsJson': EJsonValue userIdsJson} =>
        MessageReactionRealm(fromEJson(emoji), fromEJson(userIdsJson)),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(MessageReactionRealm._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      MessageReactionRealm,
      'MessageReactionRealm',
      [
        SchemaProperty('emoji', RealmPropertyType.string),
        SchemaProperty('userIdsJson', RealmPropertyType.string),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class MessageRealm extends _MessageRealm
    with RealmEntity, RealmObjectBase, RealmObject {
  MessageRealm(
    String id,
    String senderId,
    String receiverId,
    String status,
    bool edited,
    DateTime createdAt,
    DateTime updatedAt,
    bool isPending, {
    String? serverId,
    String? chatId,
    MessageContentRealm? content,
    String? deliveryStatus,
    String? readStatus,
    String? eventId,
    String? messageType,
    String? preview,
    Iterable<MessageReactionRealm> reactions = const [],
    DateTime? serverTimestamp,
    bool? isFromNotification,
    bool? isSynced,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'serverId', serverId);
    RealmObjectBase.set(this, 'chatId', chatId);
    RealmObjectBase.set(this, 'senderId', senderId);
    RealmObjectBase.set(this, 'receiverId', receiverId);
    RealmObjectBase.set(this, 'content', content);
    RealmObjectBase.set(this, 'status', status);
    RealmObjectBase.set(this, 'deliveryStatus', deliveryStatus);
    RealmObjectBase.set(this, 'readStatus', readStatus);
    RealmObjectBase.set(this, 'eventId', eventId);
    RealmObjectBase.set(this, 'messageType', messageType);
    RealmObjectBase.set(this, 'preview', preview);
    RealmObjectBase.set(this, 'edited', edited);
    RealmObjectBase.set<RealmList<MessageReactionRealm>>(
      this,
      'reactions',
      RealmList<MessageReactionRealm>(reactions),
    );
    RealmObjectBase.set(this, 'createdAt', createdAt);
    RealmObjectBase.set(this, 'updatedAt', updatedAt);
    RealmObjectBase.set(this, 'serverTimestamp', serverTimestamp);
    RealmObjectBase.set(this, 'isPending', isPending);
    RealmObjectBase.set(this, 'isFromNotification', isFromNotification);
    RealmObjectBase.set(this, 'isSynced', isSynced);
  }

  MessageRealm._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String? get serverId =>
      RealmObjectBase.get<String>(this, 'serverId') as String?;
  @override
  set serverId(String? value) => RealmObjectBase.set(this, 'serverId', value);

  @override
  String? get chatId => RealmObjectBase.get<String>(this, 'chatId') as String?;
  @override
  set chatId(String? value) => RealmObjectBase.set(this, 'chatId', value);

  @override
  String get senderId =>
      RealmObjectBase.get<String>(this, 'senderId') as String;
  @override
  set senderId(String value) => RealmObjectBase.set(this, 'senderId', value);

  @override
  String get receiverId =>
      RealmObjectBase.get<String>(this, 'receiverId') as String;
  @override
  set receiverId(String value) =>
      RealmObjectBase.set(this, 'receiverId', value);

  @override
  MessageContentRealm? get content =>
      RealmObjectBase.get<MessageContentRealm>(this, 'content')
          as MessageContentRealm?;
  @override
  set content(covariant MessageContentRealm? value) =>
      RealmObjectBase.set(this, 'content', value);

  @override
  String get status => RealmObjectBase.get<String>(this, 'status') as String;
  @override
  set status(String value) => RealmObjectBase.set(this, 'status', value);

  @override
  String? get deliveryStatus =>
      RealmObjectBase.get<String>(this, 'deliveryStatus') as String?;
  @override
  set deliveryStatus(String? value) =>
      RealmObjectBase.set(this, 'deliveryStatus', value);

  @override
  String? get readStatus =>
      RealmObjectBase.get<String>(this, 'readStatus') as String?;
  @override
  set readStatus(String? value) =>
      RealmObjectBase.set(this, 'readStatus', value);

  @override
  String? get eventId =>
      RealmObjectBase.get<String>(this, 'eventId') as String?;
  @override
  set eventId(String? value) => RealmObjectBase.set(this, 'eventId', value);

  @override
  String? get messageType =>
      RealmObjectBase.get<String>(this, 'messageType') as String?;
  @override
  set messageType(String? value) =>
      RealmObjectBase.set(this, 'messageType', value);

  @override
  String? get preview =>
      RealmObjectBase.get<String>(this, 'preview') as String?;
  @override
  set preview(String? value) => RealmObjectBase.set(this, 'preview', value);

  @override
  bool get edited => RealmObjectBase.get<bool>(this, 'edited') as bool;
  @override
  set edited(bool value) => RealmObjectBase.set(this, 'edited', value);

  @override
  RealmList<MessageReactionRealm> get reactions =>
      RealmObjectBase.get<MessageReactionRealm>(this, 'reactions')
          as RealmList<MessageReactionRealm>;
  @override
  set reactions(covariant RealmList<MessageReactionRealm> value) =>
      throw RealmUnsupportedSetError();

  @override
  DateTime get createdAt =>
      RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime;
  @override
  set createdAt(DateTime value) =>
      RealmObjectBase.set(this, 'createdAt', value);

  @override
  DateTime get updatedAt =>
      RealmObjectBase.get<DateTime>(this, 'updatedAt') as DateTime;
  @override
  set updatedAt(DateTime value) =>
      RealmObjectBase.set(this, 'updatedAt', value);

  @override
  DateTime? get serverTimestamp =>
      RealmObjectBase.get<DateTime>(this, 'serverTimestamp') as DateTime?;
  @override
  set serverTimestamp(DateTime? value) =>
      RealmObjectBase.set(this, 'serverTimestamp', value);

  @override
  bool get isPending => RealmObjectBase.get<bool>(this, 'isPending') as bool;
  @override
  set isPending(bool value) => RealmObjectBase.set(this, 'isPending', value);

  @override
  bool? get isFromNotification =>
      RealmObjectBase.get<bool>(this, 'isFromNotification') as bool?;
  @override
  set isFromNotification(bool? value) =>
      RealmObjectBase.set(this, 'isFromNotification', value);

  @override
  bool? get isSynced => RealmObjectBase.get<bool>(this, 'isSynced') as bool?;
  @override
  set isSynced(bool? value) => RealmObjectBase.set(this, 'isSynced', value);

  @override
  Stream<RealmObjectChanges<MessageRealm>> get changes =>
      RealmObjectBase.getChanges<MessageRealm>(this);

  @override
  Stream<RealmObjectChanges<MessageRealm>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<MessageRealm>(this, keyPaths);

  @override
  MessageRealm freeze() => RealmObjectBase.freezeObject<MessageRealm>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'serverId': serverId.toEJson(),
      'chatId': chatId.toEJson(),
      'senderId': senderId.toEJson(),
      'receiverId': receiverId.toEJson(),
      'content': content.toEJson(),
      'status': status.toEJson(),
      'deliveryStatus': deliveryStatus.toEJson(),
      'readStatus': readStatus.toEJson(),
      'eventId': eventId.toEJson(),
      'messageType': messageType.toEJson(),
      'preview': preview.toEJson(),
      'edited': edited.toEJson(),
      'reactions': reactions.toEJson(),
      'createdAt': createdAt.toEJson(),
      'updatedAt': updatedAt.toEJson(),
      'serverTimestamp': serverTimestamp.toEJson(),
      'isPending': isPending.toEJson(),
      'isFromNotification': isFromNotification.toEJson(),
      'isSynced': isSynced.toEJson(),
    };
  }

  static EJsonValue _toEJson(MessageRealm value) => value.toEJson();
  static MessageRealm _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'senderId': EJsonValue senderId,
        'receiverId': EJsonValue receiverId,
        'status': EJsonValue status,
        'edited': EJsonValue edited,
        'createdAt': EJsonValue createdAt,
        'updatedAt': EJsonValue updatedAt,
        'isPending': EJsonValue isPending,
      } =>
        MessageRealm(
          fromEJson(id),
          fromEJson(senderId),
          fromEJson(receiverId),
          fromEJson(status),
          fromEJson(edited),
          fromEJson(createdAt),
          fromEJson(updatedAt),
          fromEJson(isPending),
          serverId: fromEJson(ejson['serverId']),
          chatId: fromEJson(ejson['chatId']),
          content: fromEJson(ejson['content']),
          deliveryStatus: fromEJson(ejson['deliveryStatus']),
          readStatus: fromEJson(ejson['readStatus']),
          eventId: fromEJson(ejson['eventId']),
          messageType: fromEJson(ejson['messageType']),
          preview: fromEJson(ejson['preview']),
          reactions: fromEJson(ejson['reactions']),
          serverTimestamp: fromEJson(ejson['serverTimestamp']),
          isFromNotification: fromEJson(ejson['isFromNotification']),
          isSynced: fromEJson(ejson['isSynced']),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(MessageRealm._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      MessageRealm,
      'MessageRealm',
      [
        SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
        SchemaProperty('serverId', RealmPropertyType.string, optional: true),
        SchemaProperty('chatId', RealmPropertyType.string, optional: true),
        SchemaProperty('senderId', RealmPropertyType.string),
        SchemaProperty('receiverId', RealmPropertyType.string),
        SchemaProperty(
          'content',
          RealmPropertyType.object,
          optional: true,
          linkTarget: 'MessageContentRealm',
        ),
        SchemaProperty('status', RealmPropertyType.string),
        SchemaProperty(
          'deliveryStatus',
          RealmPropertyType.string,
          optional: true,
        ),
        SchemaProperty('readStatus', RealmPropertyType.string, optional: true),
        SchemaProperty('eventId', RealmPropertyType.string, optional: true),
        SchemaProperty('messageType', RealmPropertyType.string, optional: true),
        SchemaProperty('preview', RealmPropertyType.string, optional: true),
        SchemaProperty('edited', RealmPropertyType.bool),
        SchemaProperty(
          'reactions',
          RealmPropertyType.object,
          linkTarget: 'MessageReactionRealm',
          collectionType: RealmCollectionType.list,
        ),
        SchemaProperty('createdAt', RealmPropertyType.timestamp),
        SchemaProperty('updatedAt', RealmPropertyType.timestamp),
        SchemaProperty(
          'serverTimestamp',
          RealmPropertyType.timestamp,
          optional: true,
        ),
        SchemaProperty('isPending', RealmPropertyType.bool),
        SchemaProperty(
          'isFromNotification',
          RealmPropertyType.bool,
          optional: true,
        ),
        SchemaProperty('isSynced', RealmPropertyType.bool, optional: true),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class OfflineQueueRealm extends _OfflineQueueRealm
    with RealmEntity, RealmObjectBase, RealmObject {
  OfflineQueueRealm(
    String id,
    String receiverId,
    String type,
    String content,
    DateTime createdAt,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'receiverId', receiverId);
    RealmObjectBase.set(this, 'type', type);
    RealmObjectBase.set(this, 'content', content);
    RealmObjectBase.set(this, 'createdAt', createdAt);
  }

  OfflineQueueRealm._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get receiverId =>
      RealmObjectBase.get<String>(this, 'receiverId') as String;
  @override
  set receiverId(String value) =>
      RealmObjectBase.set(this, 'receiverId', value);

  @override
  String get type => RealmObjectBase.get<String>(this, 'type') as String;
  @override
  set type(String value) => RealmObjectBase.set(this, 'type', value);

  @override
  String get content => RealmObjectBase.get<String>(this, 'content') as String;
  @override
  set content(String value) => RealmObjectBase.set(this, 'content', value);

  @override
  DateTime get createdAt =>
      RealmObjectBase.get<DateTime>(this, 'createdAt') as DateTime;
  @override
  set createdAt(DateTime value) =>
      RealmObjectBase.set(this, 'createdAt', value);

  @override
  Stream<RealmObjectChanges<OfflineQueueRealm>> get changes =>
      RealmObjectBase.getChanges<OfflineQueueRealm>(this);

  @override
  Stream<RealmObjectChanges<OfflineQueueRealm>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<OfflineQueueRealm>(this, keyPaths);

  @override
  OfflineQueueRealm freeze() =>
      RealmObjectBase.freezeObject<OfflineQueueRealm>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'receiverId': receiverId.toEJson(),
      'type': type.toEJson(),
      'content': content.toEJson(),
      'createdAt': createdAt.toEJson(),
    };
  }

  static EJsonValue _toEJson(OfflineQueueRealm value) => value.toEJson();
  static OfflineQueueRealm _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'receiverId': EJsonValue receiverId,
        'type': EJsonValue type,
        'content': EJsonValue content,
        'createdAt': EJsonValue createdAt,
      } =>
        OfflineQueueRealm(
          fromEJson(id),
          fromEJson(receiverId),
          fromEJson(type),
          fromEJson(content),
          fromEJson(createdAt),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(OfflineQueueRealm._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      OfflineQueueRealm,
      'OfflineQueueRealm',
      [
        SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
        SchemaProperty('receiverId', RealmPropertyType.string),
        SchemaProperty('type', RealmPropertyType.string),
        SchemaProperty('content', RealmPropertyType.string),
        SchemaProperty('createdAt', RealmPropertyType.timestamp),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class LocalContactRealm extends _LocalContactRealm
    with RealmEntity, RealmObjectBase, RealmObject {
  LocalContactRealm(String id, String displayName, String phoneNumber) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'displayName', displayName);
    RealmObjectBase.set(this, 'phoneNumber', phoneNumber);
  }

  LocalContactRealm._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get displayName =>
      RealmObjectBase.get<String>(this, 'displayName') as String;
  @override
  set displayName(String value) =>
      RealmObjectBase.set(this, 'displayName', value);

  @override
  String get phoneNumber =>
      RealmObjectBase.get<String>(this, 'phoneNumber') as String;
  @override
  set phoneNumber(String value) =>
      RealmObjectBase.set(this, 'phoneNumber', value);

  @override
  Stream<RealmObjectChanges<LocalContactRealm>> get changes =>
      RealmObjectBase.getChanges<LocalContactRealm>(this);

  @override
  Stream<RealmObjectChanges<LocalContactRealm>> changesFor([
    List<String>? keyPaths,
  ]) => RealmObjectBase.getChangesFor<LocalContactRealm>(this, keyPaths);

  @override
  LocalContactRealm freeze() =>
      RealmObjectBase.freezeObject<LocalContactRealm>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'displayName': displayName.toEJson(),
      'phoneNumber': phoneNumber.toEJson(),
    };
  }

  static EJsonValue _toEJson(LocalContactRealm value) => value.toEJson();
  static LocalContactRealm _fromEJson(EJsonValue ejson) {
    if (ejson is! Map<String, dynamic>) return raiseInvalidEJson(ejson);
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'displayName': EJsonValue displayName,
        'phoneNumber': EJsonValue phoneNumber,
      } =>
        LocalContactRealm(
          fromEJson(id),
          fromEJson(displayName),
          fromEJson(phoneNumber),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(LocalContactRealm._);
    register(_toEJson, _fromEJson);
    return const SchemaObject(
      ObjectType.realmObject,
      LocalContactRealm,
      'LocalContactRealm',
      [
        SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
        SchemaProperty('displayName', RealmPropertyType.string),
        SchemaProperty('phoneNumber', RealmPropertyType.string),
      ],
    );
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
