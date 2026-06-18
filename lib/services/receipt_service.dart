import 'dart:convert';

import 'package:chat_app/constants/network_constants.dart';
import 'package:chat_app/core/network/api_service.dart';
import 'package:get/get.dart';

import 'storage_service.dart';

class ReceiptService extends GetxService {
  ReceiptService({ApiService? apiService, StorageService? storageService})
      : _apiService = apiService ?? Get.find<ApiService>(),
        _storageService = storageService ?? Get.find<StorageService>();

  final ApiService _apiService;
  final StorageService _storageService;

  static const String _deliveredKey = 'delivered_message_ids';
  static const String _pendingDeliveredKey = 'pending_delivered_message_ids';

  Future<void> markDelivered(List<String> messageIds) async {
    final ids = _newMessageIds(messageIds, _deliveredKey);
    if (ids.isEmpty) return;

    try {
      await _apiService.dio.post(
        NetworkConstants.deliveredReceipts,
        data: {
          'messageIds': ids,
          'deviceId': await _deviceId(),
          'deliveredAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _rememberIds(_deliveredKey, ids);
    } catch (e) {
      Get.log('Failed to send delivered receipt: $e', isError: true);
      await _rememberIds(_pendingDeliveredKey, ids);
    }
  }

  Future<void> markRead({
    required String chatId,
    required List<String> messageIds,
  }) async {
    final ids = messageIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    try {
      await _apiService.dio.post(
        NetworkConstants.readReceipts,
        data: {
          'chatId': chatId,
          'messageIds': ids,
          'deviceId': await _deviceId(),
          'readAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      Get.log('Failed to send read receipt: $e', isError: true);
    }
  }

  Future<void> flushPendingDelivered() async {
    final pending = _readIds(_pendingDeliveredKey);
    if (pending.isEmpty) return;
    await _storageService.saveString(_pendingDeliveredKey, jsonEncode(<String>[]));
    await markDelivered(pending.toList());
  }

  List<String> _newMessageIds(List<String> messageIds, String cacheKey) {
    final sent = _readIds(cacheKey);
    return messageIds
        .where((id) => id.trim().isNotEmpty && !sent.contains(id))
        .toSet()
        .toList();
  }

  Set<String> _readIds(String key) {
    final raw = _storageService.getString(key);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((id) => id.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _rememberIds(String key, List<String> ids) async {
    final current = _readIds(key)..addAll(ids);
    await _storageService.saveString(key, jsonEncode(current.toList()));
  }

  Future<String> _deviceId() async {
    var deviceId = _storageService.getString('deviceId');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = DateTime.now().microsecondsSinceEpoch.toString();
      await _storageService.saveString('deviceId', deviceId);
    }
    return deviceId;
  }
}
