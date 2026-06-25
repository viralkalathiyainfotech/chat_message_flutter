import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/color_constants.dart';
import '../../../../core/database/realm_models.dart';
import '../../domain/repositories/chat_repository.dart';
import '../controllers/chat_detail_controller.dart';

class AddExistingGroupMembersScreen extends StatefulWidget {
  const AddExistingGroupMembersScreen({
    super.key,
    required this.group,
    required this.controller,
    required this.existingMemberIds,
  });

  final UserRealm group;
  final ChatDetailController controller;
  final List<String> existingMemberIds;

  @override
  State<AddExistingGroupMembersScreen> createState() =>
      _AddExistingGroupMembersScreenState();
}

class _AddExistingGroupMembersScreenState
    extends State<AddExistingGroupMembersScreen> {
  final ChatRepository _chatRepository = Get.find<ChatRepository>();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  List<UserRealm> _allUsers = <UserRealm>[];
  List<UserRealm> _visibleUsers = <UserRealm>[];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final existingIds = widget.existingMemberIds.toSet();
      final users = await _chatRepository.getUserList();
      _allUsers = users
          .where(
            (user) => user.isGroup != true && !existingIds.contains(user.id),
          )
          .toList();
      _visibleUsers = _allUsers;
    } catch (error) {
      Get.snackbar('Add members', error.toString());
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

  Future<void> _submit() async {
    if (_selectedIds.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final success = await widget.controller.addParticipants(
      _selectedIds.toList(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Get.back(result: true);
    }
  }

  void _toggleSearch() {
    setState(() => _isSearching = !_isSearching);
    if (!_isSearching) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSearching ? _toggleSearch : Get.back,
        ),
        titleSpacing: 0,
        title: _isSearching
            ? _SearchField(controller: _searchController)
            : const Text(
                'Add members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
        ],
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 92),
              children: [
                const _SectionTitle('All users'),
                const SizedBox(height: 8),
                if (_visibleUsers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No users to add.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._visibleUsers.map(
                    (user) => _SelectableUserTile(
                      user: user,
                      selected: _selectedIds.contains(user.id),
                      onTap: () => _toggleUser(user),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _selectedIds.isEmpty
          ? const SizedBox.shrink()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConstants.primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: ColorConstants.primaryBlue
                          .withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Add Members (${_selectedIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
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
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search users...',
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(
          context,
        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SelectableUserTile extends StatelessWidget {
  const _SelectableUserTile({
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
                      radius: 19,
                      backgroundImage: hasValidPhoto
                          ? CachedNetworkImageProvider(user.photo!)
                          : null,
                      backgroundColor: Colors.grey.shade400,
                      child: hasValidPhoto
                          ? null
                          : const Icon(
                              Icons.person,
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
                            color: ColorConstants.primaryBlue,
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
