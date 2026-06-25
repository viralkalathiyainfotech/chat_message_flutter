import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/network_constants.dart';
import '../../../../core/database/realm_helper.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../utils/encryption_util.dart';
import '../../../calls/presentation/controllers/call_controller.dart';
import '../controllers/chat_detail_controller.dart';
import 'add_existing_group_members_screen.dart';

class ChatMemberInfo {
  const ChatMemberInfo({
    required this.id,
    required this.name,
    this.photo,
    this.email,
    this.mobileNumber,
  });

  final String id;
  final String name;
  final String? photo;
  final String? email;
  final String? mobileNumber;
}

List<ChatMemberInfo> chatMembersFromGroup(UserRealm group) {
  if (group.membersListJson == null || group.membersListJson!.isEmpty) {
    return const <ChatMemberInfo>[];
  }

  try {
    final decoded = jsonDecode(group.membersListJson!);
    if (decoded is! List) return const <ChatMemberInfo>[];

    return decoded.map(_memberFromPayload).whereType<ChatMemberInfo>().toList();
  } catch (error) {
    Get.log('Failed to parse group members: $error', isError: true);
    return const <ChatMemberInfo>[];
  }
}

ChatMemberInfo? _memberFromPayload(dynamic payload) {
  String id = '';
  String? name;
  String? photo;
  String? email;
  String? mobileNumber;

  if (payload is Map) {
    id = (payload['_id'] ?? payload['id'] ?? '').toString();
    name = (payload['userName'] ?? payload['name'] ?? payload['email'])
        ?.toString();
    photo = payload['photo']?.toString();
    email = payload['email']?.toString();
    mobileNumber = payload['mobileNumber']?.toString();
  } else if (payload != null) {
    id = payload.toString();
  }

  if (id.isEmpty) return null;

  final user = RealmHelper().realm.find<UserRealm>(id);
  return ChatMemberInfo(
    id: id,
    name: name ?? user?.userName ?? user?.email ?? 'Unknown User',
    photo: _validUrl(photo) ? photo : user?.photo,
    email: email ?? user?.email,
    mobileNumber: mobileNumber ?? user?.mobileNumber,
  );
}

bool _validUrl(String? value) {
  return value != null && value.startsWith('http');
}

class GroupProfileScreen extends StatefulWidget {
  const GroupProfileScreen({
    super.key,
    required this.group,
    required this.controller,
  });

  final UserRealm group;
  final ChatDetailController controller;

  @override
  State<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends State<GroupProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final members = chatMembersFromGroup(widget.group);
    final previewMembers = members.take(4).toList();
    final memberIds = members.map((member) => member.id).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.group.userName ?? 'Group',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 19),
            onPressed: () async {
              await Get.to(
                () => EditGroupInfoScreen(
                  group: widget.group,
                  controller: widget.controller,
                ),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          _ProfileAvatar(
            imageUrl: widget.group.photo,
            icon: Icons.group,
            radius: 42,
            showOnline: true,
          ),
          const SizedBox(height: 8),
          Text(
            widget.group.userName ?? 'Group',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _ActionRow(
            items: [
              _ProfileAction(
                icon: Icons.videocam_outlined,
                label: 'Video Call',
                onTap: () => Get.find<CallController>().startCall(
                  widget.group.id,
                  video: true,
                  isGroup: true,
                  participants: memberIds,
                ),
              ),
              _ProfileAction(
                icon: Icons.call_outlined,
                label: 'Voice Call',
                onTap: () => Get.find<CallController>().startCall(
                  widget.group.id,
                  video: false,
                  isGroup: true,
                  participants: memberIds,
                ),
              ),
              _ProfileAction(
                icon: Icons.search,
                label: 'Search',
                onTap: () =>
                    Get.snackbar('Search', 'Chat search is not available yet.'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'About',
            children: [
              _InfoLabel('Name', widget.group.userName ?? 'Group'),
              const SizedBox(height: 10),
              _InfoLabel('About', widget.group.bio ?? ''),
              const SizedBox(height: 10),
              _InfoLabel(
                'Created by',
                members.isEmpty ? 'Unknown' : members.first.name,
              ),
              const Divider(height: 26),
              _ChevronTile(
                icon: Icons.attach_file,
                label: 'Attach Files',
                onTap: () =>
                    Get.to(() => AttachFilesScreen(chat: widget.group)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Group Members',
            children: [
              ...previewMembers.map(
                (member) => _MemberTile(
                  member: member,
                  onMenuSelected: (action) =>
                      _handleMemberAction(action, member),
                ),
              ),
              _ChevronTile(
                label: 'View All',
                onTap: () async {
                  await Get.to(
                    () => GroupMembersScreen(
                      group: widget.group,
                      controller: widget.controller,
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PlainCard(
            child: _ChevronTile(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Add Members',
              onTap: () async {
                await Get.to(
                  () => AddExistingGroupMembersScreen(
                    group: widget.group,
                    controller: widget.controller,
                    existingMemberIds: memberIds,
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 12),
          _PlainCard(
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              title: const Text(
                'Notifications',
                style: TextStyle(fontSize: 14),
              ),
              secondary: const Icon(Icons.notifications_none, size: 18),
              activeThumbColor: ColorConstants.primaryBlue,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          const SizedBox(height: 12),
          _PlainCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red, size: 18),
              title: const Text(
                'Leave Group',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                final left = await widget.controller.leaveGroup();
                if (left) {
                  Get.back();
                  Get.back();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _PlainCard(
            child: ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 18,
              ),
              title: const Text(
                'Delete Group',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).cardColor,
                    title: const Text(
                      'Delete Group',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Are you sure you want to delete this group? This action cannot be undone.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final deleted = await widget.controller.deleteGroup();
                  if (deleted) {
                    Get.back();
                    Get.back();
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMemberAction(String action, ChatMemberInfo member) async {
    if (action == 'block') {
      await widget.controller.blockMember(member.id);
      return;
    }

    final removed = await widget.controller.removeGroupMember(member.id);
    if (removed && mounted) {
      setState(() {});
    }
  }
}

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.group,
    required this.controller,
  });

  final UserRealm group;
  final ChatDetailController controller;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  @override
  Widget build(BuildContext context) {
    final members = chatMembersFromGroup(widget.group);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Group members',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          return _MemberTile(
            member: member,
            onMenuSelected: (action) async {
              if (action == 'block') {
                await widget.controller.blockMember(member.id);
              } else {
                final removed = await widget.controller.removeGroupMember(
                  member.id,
                );
                if (removed && mounted) setState(() {});
              }
            },
          );
        },
      ),
    );
  }
}

class EditGroupInfoScreen extends StatefulWidget {
  const EditGroupInfoScreen({
    super.key,
    required this.group,
    required this.controller,
  });

  final UserRealm group;
  final ChatDetailController controller;

  @override
  State<EditGroupInfoScreen> createState() => _EditGroupInfoScreenState();
}

class _EditGroupInfoScreenState extends State<EditGroupInfoScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _aboutController;
  String? _photoPath;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.userName ?? '');
    _aboutController = TextEditingController(text: widget.group.bio ?? '');
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    setState(() => _photoPath = image.path);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isUpdating) {
      Get.snackbar('Group info', 'Please enter a group name.');
      return;
    }

    setState(() => _isUpdating = true);
    final updated = await widget.controller.updateGroupInfo(
      userName: name,
      bio: _aboutController.text.trim(),
      photoPath: _photoPath,
    );
    if (!mounted) return;
    setState(() => _isUpdating = false);
    if (updated) {
      Get.back();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_photoPath != null) {
      imageProvider = FileImage(File(_photoPath!));
    } else if (_validUrl(widget.group.photo)) {
      imageProvider = CachedNetworkImageProvider(widget.group.photo!);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Group info',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundImage: imageProvider,
                    backgroundColor: Colors.grey.shade300,
                    child: imageProvider == null
                        ? const Icon(Icons.group, size: 34)
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF555555),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _LabelledField(
            label: 'Name',
            controller: _nameController,
            maxLines: 1,
          ),
          const SizedBox(height: 18),
          _LabelledField(
            label: 'About',
            controller: _aboutController,
            maxLines: 4,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isUpdating ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ColorConstants.primaryBlue.withValues(
                  alpha: 0.45,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.user,
    required this.controller,
  });

  final UserRealm user;
  final ChatDetailController controller;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.user.userName ?? 'User',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          _ProfileAvatar(
            imageUrl: widget.user.photo,
            icon: Icons.person,
            radius: 42,
            showOnline: widget.user.isOnline == true,
          ),
          const SizedBox(height: 8),
          Text(
            widget.user.userName ?? 'User',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _ActionRow(
            items: [
              _ProfileAction(
                icon: Icons.videocam_outlined,
                label: 'Video Call',
                onTap: () => Get.find<CallController>().startCall(
                  widget.user.id,
                  video: true,
                ),
              ),
              _ProfileAction(
                icon: Icons.call_outlined,
                label: 'Voice Call',
                onTap: () => Get.find<CallController>().startCall(
                  widget.user.id,
                  video: false,
                ),
              ),
              _ProfileAction(
                icon: Icons.search,
                label: 'Search',
                onTap: () =>
                    Get.snackbar('Search', 'Chat search is not available yet.'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'About',
            children: [
              _InfoLabel('Name', widget.user.userName ?? 'User'),
              const SizedBox(height: 10),
              _InfoLabel('About', widget.user.bio ?? ''),
              const SizedBox(height: 10),
              _InfoLabel('Mobile Number', widget.user.mobileNumber ?? ''),
              const Divider(height: 26),
              _ChevronTile(
                icon: Icons.attach_file,
                label: 'Attach Files',
                onTap: () => Get.to(() => AttachFilesScreen(chat: widget.user)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PlainCard(
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              title: const Text(
                'Notifications',
                style: TextStyle(fontSize: 14),
              ),
              secondary: const Icon(Icons.notifications_none, size: 18),
              activeThumbColor: ColorConstants.primaryBlue,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          const SizedBox(height: 12),
          _PlainCard(
            child: ListTile(
              leading: const Icon(Icons.block, color: Colors.red, size: 18),
              title: const Text(
                'Block',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: widget.controller.blockUser,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatLinkInfo {
  const ChatLinkInfo({required this.link, required this.createdAt});
  final String link;
  final DateTime createdAt;
}

String _formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final target = DateTime(date.year, date.month, date.day);

  if (target == today) {
    return 'Today';
  } else if (target == yesterday) {
    return 'Yesterday';
  } else {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class AttachFilesScreen extends StatelessWidget {
  const AttachFilesScreen({super.key, required this.chat});

  final UserRealm chat;

  @override
  Widget build(BuildContext context) {
    final messages = RealmHelper().getMessagesForUser(chat.id);
    final media = messages.where(_isMediaMessage).toList();
    final docs = messages.where(_isDocMessage).toList();
    final links = _linksFromMessages(messages);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Attach Files',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          bottom: TabBar(
            indicatorColor: ColorConstants.primaryBlue,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Media'),
              Tab(text: 'Docs'),
              Tab(text: 'Links'),
            ],
          ),
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
        ),
        body: TabBarView(
          children: [
            _MediaTab(messages: media),
            _DocsTab(messages: docs),
            _LinksTab(links: links),
          ],
        ),
      ),
    );
  }

  bool _isMediaMessage(MessageRealm message) {
    final content = message.content;
    if (content == null) return false;
    return content.type == 'image' ||
        (content.type == 'file' &&
            (content.fileType?.startsWith('image/') == true ||
                content.fileType?.startsWith('video/') == true));
  }

  bool _isDocMessage(MessageRealm message) {
    final content = message.content;
    if (content == null || content.type != 'file') return false;
    return !_isMediaMessage(message);
  }

  List<ChatLinkInfo> _linksFromMessages(List<MessageRealm> messages) {
    final linkPattern = RegExp(r'https?:\/\/[^\s]+');
    final links = <ChatLinkInfo>[];
    for (final message in messages) {
      final content = message.content;
      if (content?.type != 'text' || content?.content == null) continue;
      final text = EncryptionUtil.decrypt(content!.content!);
      for (final match in linkPattern.allMatches(text)) {
        links.add(
          ChatLinkInfo(link: match.group(0)!, createdAt: message.createdAt),
        );
      }
    }
    return links;
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({required this.messages});

  final List<MessageRealm> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyInfoText('No media shared yet.');
    }

    final groups = <String, List<MessageRealm>>{};
    for (final msg in messages) {
      final header = _formatDateHeader(msg.createdAt);
      groups.putIfAbsent(header, () => []).add(msg);
    }
    final headers = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: headers.length,
      itemBuilder: (context, index) {
        final header = headers[index];
        final groupMessages = groups[header]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 16),
            Text(
              header,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: groupMessages.length,
              itemBuilder: (context, gridIndex) {
                final content = groupMessages[gridIndex].content!;
                final url = _attachmentPath(content);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _validUrl(url)
                      ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
                      : Image.file(
                          File(url ?? ''),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Theme.of(context).cardColor,
                                child: const Icon(Icons.image_not_supported),
                              ),
                        ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _DocsTab extends StatelessWidget {
  const _DocsTab({required this.messages});

  final List<MessageRealm> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyInfoText('No documents shared yet.');
    }

    final groups = <String, List<MessageRealm>>{};
    for (final msg in messages) {
      final header = _formatDateHeader(msg.createdAt);
      groups.putIfAbsent(header, () => []).add(msg);
    }
    final headers = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: headers.length,
      itemBuilder: (context, index) {
        final header = headers[index];
        final groupMessages = groups[header]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 16),
            Text(
              header,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groupMessages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, listIndex) {
                final content = groupMessages[listIndex].content!;
                final sizeStr = content.size?.isNotEmpty == true
                    ? content.size!
                    : '547.8 KB';
                final extStr =
                    content.fileType
                        ?.split('/')
                        .last
                        .replaceAll(
                          'vnd.openxmlformats-officedocument.wordprocessingml.document',
                          'docx',
                        ) ??
                    'doc';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      Icon(
                        _docIcon(content.fileType),
                        color: Colors.white70,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.content ?? 'Document',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$sizeStr • $extStr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  IconData _docIcon(String? fileType) {
    if (fileType?.contains('pdf') == true) return Icons.picture_as_pdf;
    if (fileType?.contains('audio') == true) return Icons.audiotrack;
    if (fileType?.contains('zip') == true) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}

class _LinksTab extends StatelessWidget {
  const _LinksTab({required this.links});

  final List<ChatLinkInfo> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const _EmptyInfoText('No links shared yet.');
    }

    final groups = <String, List<ChatLinkInfo>>{};
    for (final linkInfo in links) {
      final header = _formatDateHeader(linkInfo.createdAt);
      groups.putIfAbsent(header, () => []).add(linkInfo);
    }
    final headers = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: headers.length,
      itemBuilder: (context, index) {
        final header = headers[index];
        final groupLinks = groups[header]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 16),
            Text(
              header,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groupLinks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, listIndex) {
                final linkInfo = groupLinks[listIndex];
                final urlString = linkInfo.link;
                String domain = 'www.example.com';
                try {
                  final uri = Uri.parse(urlString);
                  if (uri.host.isNotEmpty) domain = uri.host;
                } catch (_) {}

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.link,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              urlString,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              domain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _EmptyInfoText extends StatelessWidget {
  const _EmptyInfoText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onMenuSelected});

  final ChatMemberInfo member;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: _ProfileAvatar(
        imageUrl: member.photo,
        icon: Icons.person,
        radius: 17,
        showOnline: false,
      ),
      title: Text(
        member.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: PopupMenuButton<String>(
        color: const Color(0xFF2F2F2F),
        icon: const Icon(Icons.more_vert, size: 16),
        onSelected: onMenuSelected,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'block',
            child: _MemberMenuItem(icon: Icons.block, label: 'Block'),
          ),
          PopupMenuItem(
            value: 'remove',
            child: _MemberMenuItem(
              icon: Icons.delete_outline,
              label: 'Remove',
              danger: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberMenuItem extends StatelessWidget {
  const _MemberMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Colors.white;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.icon,
    required this.radius,
    required this.showOnline,
  });

  final String? imageUrl;
  final IconData icon;
  final double radius;
  final bool showOnline;

  @override
  Widget build(BuildContext context) {
    final hasValidPhoto = _validUrl(imageUrl);
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundImage: hasValidPhoto
                ? CachedNetworkImageProvider(imageUrl!)
                : null,
            backgroundColor: Colors.grey.shade400,
            child: hasValidPhoto
                ? null
                : Icon(icon, color: Colors.white, size: radius * 0.9),
          ),
          if (showOnline)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.items});

  final List<_ProfileAction> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Theme.of(context).cardColor,
                  child: InkWell(
                    onTap: item.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Icon(item.icon, size: 18),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _PlainCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PlainCard extends StatelessWidget {
  const _PlainCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(color: Theme.of(context).cardColor, child: child);
  }
}

class _ChevronTile extends StatelessWidget {
  const _ChevronTile({required this.label, required this.onTap, this.icon});

  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: icon == null ? null : Icon(icon, size: 17),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({
    required this.label,
    required this.controller,
    required this.maxLines,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

String? _attachmentPath(MessageContentRealm content) {
  final value = content.fileUrl ?? content.content;
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http') || value.startsWith('/')) {
    return value.startsWith('http')
        ? value
        : '${NetworkConstants.apiRoot}${value.substring(1)}';
  }
  return value;
}
