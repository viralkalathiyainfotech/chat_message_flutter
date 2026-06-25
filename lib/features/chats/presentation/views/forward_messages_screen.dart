import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';
import '../controllers/chat_detail_controller.dart';

class ForwardMessagesScreen extends StatefulWidget {
  const ForwardMessagesScreen({
    super.key,
    required this.messages,
    required this.controller,
  });

  final List<MessageRealm> messages;
  final ChatDetailController controller;

  @override
  State<ForwardMessagesScreen> createState() => _ForwardMessagesScreenState();
}

class _ForwardMessagesScreenState extends State<ForwardMessagesScreen> {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedIds = <String>{};
  final Map<String, UserRealm> _usersById = <String, UserRealm>{};
  List<UserRealm> _allUsers = <UserRealm>[];
  List<UserRealm> _visibleUsers = <UserRealm>[];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _chatRepository.getChatList(fetchFromNetwork: false);
      final users = await _chatRepository.getUserList();
      final byId = <String, UserRealm>{};
      for (final user in [...chats, ...users]) {
        if (user.id.isEmpty) continue;
        byId[user.id] = user;
      }

      _usersById
        ..clear()
        ..addAll(byId);
      _allUsers = byId.values.toList()
        ..sort((a, b) => (a.userName ?? '').compareTo(b.userName ?? ''));
      _visibleUsers = _allUsers;
    } catch (error) {
      Get.snackbar('Forward', error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _visibleUsers = _allUsers;
        return;
      }

      _visibleUsers = _allUsers.where((user) {
        return (user.userName ?? '').toLowerCase().contains(query) ||
            (user.mobileNumber ?? '').contains(query) ||
            (user.email ?? '').toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleUser(UserRealm user) {
    setState(() {
      if (!_selectedIds.add(user.id)) {
        _selectedIds.remove(user.id);
      }
    });
  }

  Future<void> _send() async {
    if (_selectedIds.isEmpty || _isSending) return;

    final recipients = _selectedIds
        .map((id) => _usersById[id])
        .whereType<UserRealm>()
        .toList();
    if (recipients.isEmpty) return;

    setState(() => _isSending = true);
    final success = await widget.controller.forwardMessages(
      messagesToForward: widget.messages,
      recipients: recipients,
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (success) {
      Get.back(result: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedUsers = _selectedIds
        .map((id) => _usersById[id])
        .whereType<UserRealm>()
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: Get.back,
        ),
        titleSpacing: 0,
        title: Text(
          _selectedIds.isEmpty
              ? 'Forward to'
              : '${_selectedIds.length} selected',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: _SearchField(controller: _searchController),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      _selectedIds.isEmpty ? 20 : 86,
                    ),
                    itemCount: _visibleUsers.length,
                    itemBuilder: (context, index) {
                      final user = _visibleUsers[index];
                      return _ForwardUserTile(
                        user: user,
                        selected: _selectedIds.contains(user.id),
                        onTap: () => _toggleUser(user),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIds.isEmpty
          ? const SizedBox.shrink()
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 18, 12),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedUsers
                            .map((user) => user.userName ?? 'User')
                            .join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _send,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary(context),
                          disabledBackgroundColor: Colors.white70,
                          elevation: 0,
                        ),
                        child: _isSending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary(context),
                                ),
                              )
                            : const Icon(Icons.send, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Search users...',
          prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _ForwardUserTile extends StatelessWidget {
  const _ForwardUserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserRealm user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValidPhoto = user.photo != null && user.photo!.startsWith('http');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: hasValidPhoto
                          ? CachedNetworkImageProvider(user.photo!)
                          : null,
                      backgroundColor: Colors.grey.shade400,
                      child: hasValidPhoto
                          ? null
                          : Icon(
                              user.isGroup == true ? Icons.group : Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                    if (selected)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.primary(context),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.userName ?? 'Unknown User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
