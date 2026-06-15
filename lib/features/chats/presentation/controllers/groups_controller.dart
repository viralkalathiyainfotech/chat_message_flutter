import 'dart:async';
import 'package:get/get.dart';
import 'package:realm/realm.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/database/realm_helper.dart';

class GroupsController extends GetxController {
  final RxList<UserRealm> groups = <UserRealm>[].obs;
  late StreamSubscription<RealmResultsChanges<UserRealm>> _userSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadGroups();

    // Listen to changes in the database
    final allUsersResults = RealmHelper().realm.all<UserRealm>();
    _userSubscription = allUsersResults.changes.listen((event) {
      _loadGroups();
    });
  }

  @override
  void onClose() {
    _userSubscription.cancel();
    super.onClose();
  }

  void _loadGroups() {
    // Query all UserRealms where isGroup is true
    final dbGroups = RealmHelper().realm.all<UserRealm>().where((u) => u.isGroup == true).toList();
    
    // Sort them alphabetically or by creation date (we'll just use alphabetical for Groups tab unless specified)
    dbGroups.sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
    
    groups.assignAll(dbGroups);
  }
}
