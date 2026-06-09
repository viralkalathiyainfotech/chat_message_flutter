import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/database/realm_models.dart';
import '../../data/chat_repository.dart';

class NewChatController extends GetxController {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  
  final RxList<UserRealm> searchResults = <UserRealm>[].obs;
  final RxBool isLoading = true.obs;
  
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    _loadInitialUsers();
    searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadInitialUsers() async {
    isLoading.value = true;
    searchResults.value = await _chatRepository.searchUsers('');
    isLoading.value = false;
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    // Simulate API search with debounce
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final query = searchController.text.trim();
      isLoading.value = true;
      searchResults.value = await _chatRepository.searchUsers(query);
      isLoading.value = false;
    });
  }

  @override
  void onClose() {
    searchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }
}
