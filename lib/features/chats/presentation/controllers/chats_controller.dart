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

  late StreamSubscription<RealmResultsChanges<MessageRealm>> _messageSubscription;
  late RealmResults<MessageRealm> _allMessagesResults;

  @override
  void onInit() {
    super.onInit();
    _loadChats();
    
    // Auto-update the list order when any message changes
    _allMessagesResults = RealmHelper().realm.all<MessageRealm>();
    _messageSubscription = _allMessagesResults.changes.listen((event) {
      _sortAndUpdateChats();
    });
  }

  @override
  void onClose() {
    _messageSubscription.cancel();
    super.onClose();
  }

  Future<void> _loadChats() async {
    // 1. Load instantly from local database
    isLoading.value = true;
    final localChats = await _chatRepository.getChatList(fetchFromNetwork: false);
    recentChats.assignAll(localChats);
    _sortAndUpdateChats();
    isLoading.value = false;
    
    // 2. Sync in background
    _syncChats();
  }

  Future<void> _syncChats() async {
    isSyncing.value = true;
    final syncedChats = await _chatRepository.getChatList(fetchFromNetwork: true);
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
       if (msgA == null) return 1;
       if (msgB == null) return -1;
       
       return msgB.createdAt.compareTo(msgA.createdAt);
    });
    recentChats.assignAll(chats);
    recentChats.refresh();
  }
}
