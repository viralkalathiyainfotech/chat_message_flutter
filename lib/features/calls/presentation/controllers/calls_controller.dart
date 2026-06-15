import 'dart:async';
import 'package:get/get.dart';
import 'package:realm/realm.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/database/realm_helper.dart';

class CallRecord {
  final UserRealm user;
  final MessageRealm message;
  
  CallRecord(this.user, this.message);
}

class CallsController extends GetxController {
  final RxList<CallRecord> calls = <CallRecord>[].obs;
  late StreamSubscription<RealmResultsChanges<MessageRealm>> _messageSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadCalls();

    final allMessages = RealmHelper().realm.all<MessageRealm>();
    _messageSubscription = allMessages.changes.listen((event) {
      _loadCalls();
    });
  }

  @override
  void onClose() {
    _messageSubscription.cancel();
    super.onClose();
  }

  void _loadCalls() {
    // Query all messages where content.type == 'call', sorted by createdAt DESC
    final allCallMessages = RealmHelper().realm.all<MessageRealm>()
        .where((m) => m.content?.type == 'call')
        .toList();
    
    allCallMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final List<CallRecord> callRecords = [];
    final seenUsers = <String>{};

    for (var msg in allCallMessages) {
      // Find the other user
      // Assume current user ID is myUserId (should use Get.find<StorageService>().getUserId() in a real app,
      // but here we can just see who the other user is based on senderId/receiverId vs the users list).
      // We'll just fetch the UserRealm matching either senderId or receiverId.
      
      final dbUsers = RealmHelper().realm.query<UserRealm>('id == \$0 OR id == \$1', [msg.senderId, msg.receiverId]);
      
      UserRealm? otherUser;
      if (dbUsers.length > 1) {
        // If both are in DB, we need to know our own ID to pick the OTHER user.
        // Usually, one of them is in the DB.
        // For now, pick the first one that has a valid name.
        otherUser = dbUsers.first;
      } else if (dbUsers.isNotEmpty) {
        otherUser = dbUsers.first;
      }

      if (otherUser != null && !seenUsers.contains(otherUser.id)) {
        seenUsers.add(otherUser.id);
        callRecords.add(CallRecord(otherUser, msg));
      }
    }

    calls.assignAll(callRecords);
  }
}
