import 'dart:convert';

import 'package:chat_app/core/database/realm_helper.dart';
import 'package:chat_app/core/database/realm_models.dart';
import 'package:chat_app/features/chats/presentation/views/chat_detail_screen.dart';
import 'package:get/get.dart';

class NotificationNavigationService extends GetxService {
  final RealmHelper _realmHelper = RealmHelper();
  final List<Map<String, dynamic>> _pendingPayloads = [];
  bool _ready = false;

  void markReady() {
    _ready = true;
    for (final payload in List<Map<String, dynamic>>.from(_pendingPayloads)) {
      openChat(payload);
    }
    _pendingPayloads.clear();
  }

  void openChatFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        openChat(decoded);
      } else if (decoded is Map) {
        openChat(decoded.map((key, value) => MapEntry(key.toString(), value)));
      }
    } catch (e) {
      Get.log('Invalid notification payload: $e', isError: true);
    }
  }

  void openChat(Map<String, dynamic> payload) {
    if (!_ready) {
      _pendingPayloads.add(payload);
      return;
    }

    final chatId = (payload['chatId'] ?? payload['chat_id'])?.toString();
    if (chatId == null || chatId.isEmpty || !_realmHelper.isInitialized) {
      return;
    }

    final existing = _realmHelper.realm.find<UserRealm>(chatId);
    final user =
        existing ??
        UserRealm(
          chatId,
          userName:
              payload['chatName']?.toString() ??
              payload['chat_name']?.toString() ??
              payload['senderName']?.toString() ??
              payload['sender_name']?.toString() ??
              (payload['isGroup'] == true || payload['is_group'] == 'true'
                  ? 'Group'
                  : 'Chat'),
          isGroup: payload['isGroup'] == true || payload['is_group'] == 'true',
        );

    if (existing == null) {
      _realmHelper.saveUsers([user]);
    }

    Get.to(() => ChatDetailScreen(user: user));
  }
}
