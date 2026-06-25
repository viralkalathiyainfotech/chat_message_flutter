import 'package:flutter/material.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/chat_detail_controller.dart';

class ContactItem {
  final String name;
  final String phone;
  final String avatarUrl;

  ContactItem({
    required this.name,
    required this.phone,
    required this.avatarUrl,
  });
}

class SendContactScreen extends StatefulWidget {
  final ChatDetailController chatController;

  const SendContactScreen({super.key, required this.chatController});

  @override
  State<SendContactScreen> createState() => _SendContactScreenState();
}

class _SendContactScreenState extends State<SendContactScreen> {
  final List<ContactItem> _allContacts = [
    ContactItem(
      name: 'Isabella Anderson',
      phone: '+91 12345 67890',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
    ),
    ContactItem(
      name: 'Mia Taylor',
      phone: '+91 12345 67890',
      avatarUrl: 'https://i.pravatar.cc/150?img=2',
    ),
    ContactItem(
      name: 'William Davis',
      phone: '+91 12345 67890',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
    ),
    ContactItem(
      name: 'James Rodriguez',
      phone: '+91 12345 67891',
      avatarUrl: 'https://i.pravatar.cc/150?img=4',
    ),
    ContactItem(
      name: 'Sarah Williams',
      phone: '+91 12345 67892',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
    ),
    ContactItem(
      name: 'Michael Jones',
      phone: '+91 12345 67893',
      avatarUrl: 'https://i.pravatar.cc/150?img=6',
    ),
    ContactItem(
      name: 'Christopher White',
      phone: '+91 12345 67894',
      avatarUrl: 'https://i.pravatar.cc/150?img=7',
    ),
  ];

  List<ContactItem> _filteredContacts = [];
  final Set<ContactItem> _selectedContacts = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredContacts = List.from(_allContacts);
    _loadDeviceContacts();
  }

  Future<void> _loadDeviceContacts() async {
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _isLoading = false;
    });
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_allContacts);
      } else {
        _filteredContacts = _allContacts
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedContacts.isNotEmpty;
    final selectedText = _selectedContacts.length > 2
        ? '${_selectedContacts.length} selected'
        : _selectedContacts.map((c) => c.name).join(', ');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          hasSelection
              ? '${_selectedContacts.length} selected'
              : 'Send Contact',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: ColorConstants.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterContacts,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(
                  color: ColorConstants.primaryBlue,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final isSelected = _selectedContacts.contains(contact);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedContacts.remove(contact);
                          } else {
                            _selectedContacts.add(contact);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ColorConstants.primaryBlue
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? ColorConstants.primaryBlue
                                      : Colors.grey.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: NetworkImage(
                                    contact.avatarUrl,
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: ColorConstants.primaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    contact.phone,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (hasSelection)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: ColorConstants.inputBackground,
                  border: Border(
                    top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        for (final contact in _selectedContacts) {
                          await widget.chatController.sendContactMessage(
                            contact.name,
                            contact.phone,
                          );
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ColorConstants.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
