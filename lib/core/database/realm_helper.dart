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
      OfflineQueueRealm.schema,
    ]);
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

  List<MessageRealm> getMessagesForUser(String userId) {
    return _realm.query<MessageRealm>('senderId == \$0 OR receiverId == \$0 SORT(createdAt ASC)', [userId]).toList();
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
}
