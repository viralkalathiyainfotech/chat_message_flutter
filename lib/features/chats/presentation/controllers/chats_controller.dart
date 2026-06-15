import 'dart:async';
import 'package:get/get.dart';
import 'package:realm/realm.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/database/realm_helper.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatsController extends GetxController {
  final ChatRepository _chatRepository = Get.put(ChatRepository());
  final RxList<UserRealm> recentChats = <UserRealm>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSyncing = false.obs;
  final RxInt updateTrigger = 0.obs;

  late StreamSubscription<RealmResultsChanges<MessageRealm>>
  _messageSubscription;
  late StreamSubscription<RealmResultsChanges<UserRealm>> _userSubscription;
  late RealmResults<MessageRealm> _allMessagesResults;
  late RealmResults<UserRealm> _allUsersResults;

  @override
  void onInit() {
    super.onInit();
    _loadChats();

    // Listen to ALL messages to re-sort chats when new messages arrive
    _allMessagesResults = RealmHelper().realm.all<MessageRealm>();
    _messageSubscription = _allMessagesResults.changes.listen((event) {
      _sortAndUpdateChats();
    });

    _allUsersResults = RealmHelper().realm.all<UserRealm>();
    _userSubscription = _allUsersResults.changes.listen((event) async {
      final localChats = await _chatRepository.getChatList(
        fetchFromNetwork: false,
      );
      recentChats.assignAll(localChats);
      _sortAndUpdateChats();
    });
  }

  @override
  void onClose() {
    _messageSubscription.cancel();
    _userSubscription.cancel();
    super.onClose();
  }

  Future<void> _loadChats() async {
    // 1. Load instantly from local database
    isLoading.value = true;
    final localChats = await _chatRepository.getChatList(
      fetchFromNetwork: false,
    );
    recentChats.assignAll(localChats);
    _sortAndUpdateChats();
    isLoading.value = false;

    // 2. Sync in background
    _syncChats();
  }

  Future<void> _syncChats() async {
    isSyncing.value = true;
    final syncedChats = await _chatRepository.getChatList(
      fetchFromNetwork: true,
    );
    recentChats.assignAll(syncedChats);
    _sortAndUpdateChats();
    isSyncing.value = false;
  }

  void _sortAndUpdateChats() {
    if (recentChats.isEmpty) return;

    final chats = List<UserRealm>.from(recentChats);
    chats.sort((a, b) {
      final msgA = RealmHelper().getLastMessageForUser(a.id);
      final msgB = RealmHelper().getLastMessageForUser(b.id);

      if (msgA == null && msgB == null) return 0;
      // We place chats with NO messages at the TOP so new groups/chats are easily visible
      if (msgA == null) return -1;
      if (msgB == null) return 1;

      return msgB.createdAt.compareTo(msgA.createdAt);
    });
    recentChats.assignAll(chats);
    recentChats.refresh();
    updateTrigger.value++;
  }
}
