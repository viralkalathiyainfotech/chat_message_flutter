import 'package:get/get.dart';
import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatsController extends GetxController {
  final ChatRepository _chatRepository = Get.put(ChatRepository());
  final RxList<UserRealm> recentChats = <UserRealm>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadChats();
  }

  Future<void> _loadChats() async {
    isLoading.value = true;
    final chats = await _chatRepository.getChatList();
    recentChats.value = chats;
    isLoading.value = false;
  }
}
