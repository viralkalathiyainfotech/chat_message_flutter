import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';

class NewChatController extends GetxController {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  
  final RxList<UserRealm> searchResults = <UserRealm>[].obs;
  final RxList<LocalContactRealm> unregisteredContacts = <LocalContactRealm>[].obs;
  
  List<UserRealm> _allRegisteredUsers = [];
  List<LocalContactRealm> _allUnregisteredContacts = [];

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
    
    // Sync and fetch local contacts
    final localContacts = await _chatRepository.syncContacts();
    
    // Fetch registered contacts from backend
    _allRegisteredUsers = await _chatRepository.getUserList();
    
    // Determine unregistered contacts by checking phone numbers
    final registeredPhones = _allRegisteredUsers.map((u) {
      final phone = u.mobileNumber ?? '';
      return phone.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    }).toSet();
    
    _allUnregisteredContacts = localContacts.where((lc) {
      return !registeredPhones.contains(lc.phoneNumber);
    }).toList();

    searchResults.value = _allRegisteredUsers;
    unregisteredContacts.value = _allUnregisteredContacts;
    
    isLoading.value = false;
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        searchResults.value = _allRegisteredUsers;
        unregisteredContacts.value = _allUnregisteredContacts;
      } else {
        searchResults.value = _allRegisteredUsers.where((u) =>
          (u.userName ?? '').toLowerCase().contains(query) ||
          (u.email ?? '').toLowerCase().contains(query) ||
          (u.mobileNumber ?? '').contains(query)
        ).toList();
        
        unregisteredContacts.value = _allUnregisteredContacts.where((lc) =>
          lc.displayName.toLowerCase().contains(query) ||
          lc.phoneNumber.contains(query)
        ).toList();
      }
    });
  }

  @override
  void onClose() {
    searchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }
}
