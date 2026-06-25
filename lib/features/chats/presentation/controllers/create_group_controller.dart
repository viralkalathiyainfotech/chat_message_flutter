import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';

class CreateGroupController extends GetxController {
  CreateGroupController({
    ChatRepository? chatRepository,
    ImagePicker? imagePicker,
  }) : _chatRepository = chatRepository ?? Get.find<ChatRepository>(),
       _imagePicker = imagePicker ?? ImagePicker();

  final ChatRepository _chatRepository;
  final ImagePicker _imagePicker;

  final TextEditingController groupNameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  final RxBool isLoading = true.obs;
  final RxBool isCreating = false.obs;
  final RxBool isSearching = false.obs;
  final RxList<UserRealm> users = <UserRealm>[].obs;
  final RxList<LocalContactRealm> inviteContacts = <LocalContactRealm>[].obs;
  final RxList<String> selectedMemberIds = <String>[].obs;
  final RxString photoPath = ''.obs;

  List<UserRealm> _allUsers = [];
  List<LocalContactRealm> _allInviteContacts = [];
  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_onSearchChanged);
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    isLoading.value = true;
    try {
      final localContacts = await _chatRepository.syncContacts();
      _allUsers = await _chatRepository.getUserList();

      final registeredPhones = _allUsers.map((user) {
        final phone = user.mobileNumber ?? '';
        return _normalizePhone(phone);
      }).toSet();

      _allInviteContacts = localContacts
          .where((contact) => !registeredPhones.contains(contact.phoneNumber))
          .toList();

      users.assignAll(_allUsers);
      inviteContacts.assignAll(_allInviteContacts);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickPhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    photoPath.value = image.path;
  }

  void toggleSearch() {
    if (isSearching.value) {
      stopSearch();
    } else {
      isSearching.value = true;
    }
  }

  void stopSearch() {
    searchController.clear();
    isSearching.value = false;
    users.assignAll(_allUsers);
    inviteContacts.assignAll(_allInviteContacts);
  }

  void toggleMember(UserRealm user) {
    if (selectedMemberIds.contains(user.id)) {
      selectedMemberIds.remove(user.id);
    } else {
      selectedMemberIds.add(user.id);
    }
  }

  bool isSelected(UserRealm user) => selectedMemberIds.contains(user.id);

  Future<UserRealm?> createGroup() async {
    final groupName = groupNameController.text.trim();
    final about = aboutController.text.trim();

    if (groupName.isEmpty) {
      Get.snackbar('Create group', 'Please enter a group name.');
      return null;
    }

    if (selectedMemberIds.isEmpty) {
      Get.snackbar('Create group', 'Please add at least one member.');
      return null;
    }

    isCreating.value = true;
    try {
      return await _chatRepository.createGroup(
        userName: groupName,
        memberIds: selectedMemberIds.toList(),
        bio: about.isEmpty ? null : about,
        photoPath: photoPath.value.isEmpty ? null : photoPath.value,
      );
    } catch (error) {
      Get.snackbar('Create group', error.toString());
      return null;
    } finally {
      isCreating.value = false;
    }
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      final query = searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        users.assignAll(_allUsers);
        inviteContacts.assignAll(_allInviteContacts);
        return;
      }

      users.assignAll(
        _allUsers.where((user) {
          return (user.userName ?? '').toLowerCase().contains(query) ||
              (user.mobileNumber ?? '').contains(query) ||
              (user.email ?? '').toLowerCase().contains(query);
        }).toList(),
      );

      inviteContacts.assignAll(
        _allInviteContacts.where((contact) {
          return contact.displayName.toLowerCase().contains(query) ||
              contact.phoneNumber.contains(query);
        }).toList(),
      );
    });
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
  }

  @override
  void onClose() {
    groupNameController.dispose();
    aboutController.dispose();
    searchController.dispose();
    _searchDebounce?.cancel();
    super.onClose();
  }
}
