import 'package:get/get.dart';

import '../core/database/realm_helper.dart';
import 'call_service.dart';
import 'socket_service.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class SessionPrivacyService extends GetxService {
  final StorageService _storageService = Get.find<StorageService>();
  final RealmHelper _realmHelper = RealmHelper();

  Future<void> resetForAccountSwitch(String nextUserId) async {
    final previousUserId = _storageService.getString('user_id');
    if (previousUserId == null || previousUserId == nextUserId) return;
    await clearUserSessionData(clearCredentials: false);
  }

  Future<void> clearUserSessionData({bool clearCredentials = true}) async {
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().disconnect();
    }

    if (Get.isRegistered<CallService>()) {
      try {
        Get.find<CallService>().endCall();
      } catch (_) {}
    }

    if (Get.isRegistered<SyncService>()) {
      Get.find<SyncService>().activeChatUserId.value = null;
      Get.find<SyncService>().typingUsers.clear();
      Get.find<SyncService>().typingUserIdsByChat.clear();
    }

    if (_realmHelper.isInitialized) {
      _realmHelper.clearUserScopedData();
    }

    if (clearCredentials) {
      await _storageService.clearUserScopedPreferences();
    }
  }
}
