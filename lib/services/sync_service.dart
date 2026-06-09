import 'package:get/get.dart';
import '../core/database/realm_helper.dart';
import 'connectivity_service.dart';

class SyncService extends GetxService {
  final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  final RealmHelper _realmHelper = RealmHelper();

  @override
  void onInit() {
    super.onInit();
    // Listen to network changes
    ever(_connectivityService.isOnline, (bool isOnline) {
      if (isOnline) {
        _syncOfflineMessages();
      }
    });
  }

  Future<void> _syncOfflineMessages() async {
    Get.log('Network restored. Checking offline queue...');
    final queue = _realmHelper.getQueue();
    
    if (queue.isEmpty) {
      Get.log('No offline messages to sync.');
      return;
    }

    Get.log('Syncing ${queue.length} offline messages...');
    
    for (var queuedMsg in queue) {
      try {
        // Call ChatRepository or ApiService to send the message to the backend
        // Example: await Get.find<ChatRepository>().sendRealtimeMessage(queuedMsg.receiverId, queuedMsg.content, queuedMsg.type);
        
        // Once successfully sent, remove from queue
        _realmHelper.removeFromQueue(queuedMsg.id);
        
        // Also update the message status in the main MessageRealm from pending to sent
        // (This logic will be handled by the ChatRepository update)
        
      } catch (e) {
        Get.log('Failed to sync message ${queuedMsg.id}: $e', isError: true);
        // Will retry next time we go online
      }
    }
  }
}
