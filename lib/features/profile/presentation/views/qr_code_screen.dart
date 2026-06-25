import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../constants/color_constants.dart';
import '../controllers/profile_controller.dart';

class QrCodeScreen extends StatelessWidget {
  QrCodeScreen({super.key});

  final ProfileController controller = Get.find<ProfileController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'QR code',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Obx(() {
          final isMyCode = controller.activeQrTab.value == 'My Code';
          final user = controller.currentUser.value;
          return Stack(
            children: [
              Column(
                children: [
                  // Toggle Tab Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => controller.setActiveQrTab('My Code'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isMyCode ? ColorConstants.primaryBlue : ColorConstants.inputBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: isMyCode ? null : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'My Code',
                                style: TextStyle(
                                  color: isMyCode ? Colors.white : ColorConstants.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => controller.setActiveQrTab('Scan'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: !isMyCode ? ColorConstants.primaryBlue : ColorConstants.inputBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: !isMyCode ? null : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Scan',
                                style: TextStyle(
                                  color: !isMyCode ? Colors.white : ColorConstants.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Content View
                  Expanded(
                    child: isMyCode
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 24.0),
                              decoration: BoxDecoration(
                                color: ColorConstants.primaryBlue,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: ColorConstants.primaryBlue.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white,
                                    backgroundImage: (user?.photo != null && user!.photo!.isNotEmpty)
                                        ? CachedNetworkImageProvider(user.photo!)
                                        : null,
                                    child: (user?.photo == null || user!.photo!.isEmpty)
                                        ? Icon(Icons.person, size: 40, color: ColorConstants.primaryBlue)
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    user?.userName ?? 'Wade Warmen',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (user?.mobileNumber != null && user!.mobileNumber!.isNotEmpty)
                                        ? user.mobileNumber!
                                        : '+91 85320 59232',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_2,
                                      size: 180,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white54,
                                    size: 64,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final mockData = '{"sessionId":"mock_session_123","timestamp":"${DateTime.now().toIso8601String()}"}';
                                    controller.scanQrCode(mockData);
                                  },
                                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                  label: const Text(
                                    'Simulate QR Scan',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorConstants.primaryBlue,
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              if (controller.isLoading.value)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ColorConstants.primaryBlue,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
