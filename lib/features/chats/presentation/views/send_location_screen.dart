import 'package:flutter/material.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/chat_detail_controller.dart';

class SendLocationScreen extends StatefulWidget {
  final ChatDetailController chatController;

  const SendLocationScreen({super.key, required this.chatController});

  @override
  State<SendLocationScreen> createState() => _SendLocationScreenState();
}

class _SendLocationScreenState extends State<SendLocationScreen> {
  bool _isShareLiveMode = false;
  String _selectedDuration = '15 minutes';
  final TextEditingController _captionController = TextEditingController();

  final List<Map<String, String>> _nearbyPlaces = [
    {'title': '23 Safwan Al-Masri Street', 'subtitle': 'Varachha'},
    {'title': '35 Yuoisf Al-Thaqafi Street', 'subtitle': 'Varachha'},
    {'title': '12 King Faisal Road', 'subtitle': 'Downtown'},
    {'title': '48 Al-Olaya Street', 'subtitle': 'Business District'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Send location',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () {
            if (_isShareLiveMode) {
              setState(() {
                _isShareLiveMode = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Map Preview Container
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=1000&auto=format&fit=crop',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(color: Colors.white.withValues(alpha: 0.1)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: ColorConstants.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/150?img=8',
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: ColorConstants.primaryBlue,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Action View
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _isShareLiveMode
                  ? _buildShareLiveLocationView()
                  : _buildDefaultView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _isShareLiveMode = true;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: ColorConstants.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.share_location,
                    color: Colors.blueAccent.shade200,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Share Live location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Nearby places',
            style: TextStyle(
              color: ColorConstants.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () {
              widget.chatController.sendLocationMessage(isLive: false);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: ColorConstants.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    color: Colors.blueAccent.shade200,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Send Current Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _nearbyPlaces.length,
          itemBuilder: (context, index) {
            final place = _nearbyPlaces[index];
            return InkWell(
              onTap: () {
                widget.chatController.sendLocationMessage(
                  isLive: false,
                  caption: '${place['title']}, ${place['subtitle']}',
                );
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ColorConstants.inputBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place['title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            place['subtitle'] ?? '',
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildShareLiveLocationView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Live location',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildDurationButton('15 minutes'),
              const SizedBox(width: 12),
              _buildDurationButton('1 hour'),
              const SizedBox(width: 12),
              _buildDurationButton('8 hour'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: ColorConstants.inputBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Type Message...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  widget.chatController.sendLocationMessage(
                    isLive: true,
                    duration: _selectedDuration,
                    caption: _captionController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ColorConstants.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDurationButton(String duration) {
    final isSelected = _selectedDuration == duration;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDuration = duration;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? ColorConstants.primaryBlue
                : ColorConstants.inputBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            duration,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
