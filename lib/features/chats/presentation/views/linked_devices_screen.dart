import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/color_constants.dart';
import '../controllers/linked_devices_controller.dart';
import 'linked_device_scanner_screen.dart';

class LinkedDevicesScreen extends StatelessWidget {
  LinkedDevicesScreen({super.key});

  final LinkedDevicesController controller =
      Get.isRegistered<LinkedDevicesController>()
      ? Get.find<LinkedDevicesController>()
      : Get.put(LinkedDevicesController());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : const Color(0xFF111111);
    final mutedColor = foregroundColor.withValues(alpha: 0.58);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Linked devices',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.devices.isEmpty) {
            return _LinkedDevicesError(
              message: controller.errorMessage.value,
              onRetry: () => controller.loadDevices(),
            );
          }

          if (controller.devices.isEmpty) {
            return _EmptyLinkedDevices(
              foregroundColor: foregroundColor,
              mutedColor: mutedColor,
              onLinkDevice: _openScanner,
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.loadDevices(showLoading: false),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
              children: [
                _HeroContent(
                  foregroundColor: foregroundColor,
                  mutedColor: mutedColor,
                ),
                const SizedBox(height: 26),
                _LinkDeviceButton(onPressed: _openScanner),
                const SizedBox(height: 20),
                Text(
                  'Devices',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                ...controller.devices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LinkedDeviceTile(
                      device: device,
                      lastActive: controller.formatLastActive(device),
                      isLoggingOut:
                          controller.loggingOutDeviceId.value ==
                          device.deviceId,
                      onLogout: () => _confirmLogout(device),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _openScanner() async {
    final linked = await Get.to<bool>(() => LinkedDeviceScannerScreen());
    if (linked == true) {
      await controller.loadDevices(showLoading: false);
    }
  }

  Future<void> _confirmLogout(LinkedDevice device) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Logout device?'),
        content: Text('${device.deviceName} will be logged out from ChatApp.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.logoutDevice(device);
    }
  }
}

class _EmptyLinkedDevices extends StatelessWidget {
  const _EmptyLinkedDevices({
    required this.foregroundColor,
    required this.mutedColor,
    required this.onLinkDevice,
  });

  final Color foregroundColor;
  final Color mutedColor;
  final VoidCallback onLinkDevice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HeroContent(
                  foregroundColor: foregroundColor,
                  mutedColor: mutedColor,
                ),
                const SizedBox(height: 36),
                _LinkDeviceButton(onPressed: onLinkDevice),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.foregroundColor, required this.mutedColor});

  final Color foregroundColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.devices_other, color: mutedColor, size: 64),
        const SizedBox(height: 18),
        Text(
          'Use Chats on other devices',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Send and receive messages from your browser or desktop app after scanning a secure QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _LinkDeviceButton extends StatelessWidget {
  const _LinkDeviceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: const Text(
          'Linked Device',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LinkedDeviceTile extends StatelessWidget {
  const _LinkedDeviceTile({
    required this.device,
    required this.lastActive,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final LinkedDevice device;
  final String lastActive;
  final bool isLoggingOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final foregroundColor = isDark ? Colors.white : const Color(0xFF111111);
    final mutedColor = foregroundColor.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: foregroundColor.withValues(alpha: 0.08),
            ),
            child: Icon(
              device.isDesktop ? Icons.desktop_windows : Icons.devices,
              color: mutedColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lastActive,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: isLoggingOut ? null : onLogout,
            style: TextButton.styleFrom(
              minimumSize: const Size(62, 30),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              disabledForegroundColor: Colors.red.withValues(alpha: 0.45),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoggingOut
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                : const Text(
                    'Logout',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LinkedDevicesError extends StatelessWidget {
  const _LinkedDevicesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
