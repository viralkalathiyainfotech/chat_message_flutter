import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:realm/realm.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/database/realm_helper.dart';
import '../../../../services/storage_service.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatsController extends GetxController {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final RxList<UserRealm> recentChats = <UserRealm>[].obs;
  final RxBool isArchiveView = false.obs;
  final RxBool isLoading = true.obs;
  final RxBool isSyncing = false.obs;
  final RxInt updateTrigger = 0.obs;
  final RxSet<String> archivedChatIds = <String>{}.obs;
  final List<UserRealm> _allChats = <UserRealm>[];

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
      _setAllChats(localChats);
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
    _loadArchivedChatIds();
    final localChats = await _chatRepository.getChatList(
      fetchFromNetwork: false,
    );
    _setAllChats(localChats);
    _sortAndUpdateChats();
    isLoading.value = false;

    // 2. Sync in background
    _syncChats();
  }

  Future<void> reloadLocalChats() async {
    _loadArchivedChatIds();
    final localChats = await _chatRepository.getChatList(
      fetchFromNetwork: false,
    );
    _setAllChats(localChats);
    _sortAndUpdateChats();
  }

  Future<void> _syncChats() async {
    isSyncing.value = true;
    final syncedChats = await _chatRepository.getChatList(
      fetchFromNetwork: true,
    );
    _loadArchivedChatIds();
    _setAllChats(syncedChats);
    _sortAndUpdateChats();
    isSyncing.value = false;
  }

  String get chatListTitle => isArchiveView.value ? 'Archived' : 'Recent';

  String get emptyMessage => isArchiveView.value
      ? 'No archived chats.'
      : 'No chats yet.\nStart a conversation!';

  void toggleArchiveView() {
    isArchiveView.toggle();
    _sortAndUpdateChats();
  }

  void _sortAndUpdateChats() {
    final visibleChats = _allChats.where((chat) {
      final isArchived = archivedChatIds.contains(chat.id);
      return isArchiveView.value ? isArchived : !isArchived;
    }).toList();

    if (visibleChats.isEmpty) {
      recentChats.clear();
      updateTrigger.value++;
      return;
    }

    visibleChats.sort((a, b) {
      final msgA = RealmHelper().getLastMessageForUser(a.id);
      final msgB = RealmHelper().getLastMessageForUser(b.id);

      if (msgA == null && msgB == null) return 0;
      // We place chats with NO messages at the BOTTOM
      if (msgA == null) return 1;
      if (msgB == null) return -1;

      return msgB.createdAt.compareTo(msgA.createdAt);
    });
    recentChats.assignAll(visibleChats);
    recentChats.refresh();
    updateTrigger.value++;
  }

  void _setAllChats(List<UserRealm> chats) {
    _allChats
      ..clear()
      ..addAll(chats);
  }

  void _loadArchivedChatIds() {
    final raw = Get.find<StorageService>().getString(
      ChatRepository.archivedChatIdsKey,
    );
    if (raw == null || raw.isEmpty) {
      archivedChatIds.clear();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        archivedChatIds.assignAll(
          decoded
              .map((id) => id?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
      }
    } catch (error) {
      Get.log('Failed to parse archived chat ids: $error', isError: true);
      archivedChatIds.clear();
    }
  }
}
