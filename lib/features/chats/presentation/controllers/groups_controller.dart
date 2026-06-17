import 'dart:async';
import 'package:get/get.dart';
import 'package:realm/realm.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/database/realm_helper.dart';

class GroupsController extends GetxController {
  final RxList<UserRealm> groups = <UserRealm>[].obs;
  final RxInt updateTrigger = 0.obs;
  late StreamSubscription<RealmResultsChanges<UserRealm>> _userSubscription;
  late StreamSubscription<RealmResultsChanges<MessageRealm>>
  _messageSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadGroups();

    // Listen to changes in the database
    final allUsersResults = RealmHelper().realm.all<UserRealm>();
    _userSubscription = allUsersResults.changes.listen((event) {
      _loadGroups();
    });

    final allMessagesResults = RealmHelper().realm.all<MessageRealm>();
    _messageSubscription = allMessagesResults.changes.listen((event) {
      _loadGroups();
    });
  }

  @override
  void onClose() {
    _userSubscription.cancel();
    _messageSubscription.cancel();
    super.onClose();
  }

  void reloadLocalGroups() {
    _loadGroups();
  }

  void _loadGroups() {
    // Query all UserRealms where isGroup is true
    final dbGroups = RealmHelper().realm
        .all<UserRealm>()
        .where((u) => u.isGroup == true)
        .toList();

    dbGroups.sort((a, b) {
      final msgA = RealmHelper().getLastMessageForUser(a.id);
      final msgB = RealmHelper().getLastMessageForUser(b.id);

      if (msgA == null && msgB == null) {
        return (a.userName ?? '').compareTo(b.userName ?? '');
      }
      if (msgA == null) return 1;
      if (msgB == null) return -1;
      return msgB.createdAt.compareTo(msgA.createdAt);
    });

    groups.assignAll(dbGroups);
    updateTrigger.value++;
  }
}
