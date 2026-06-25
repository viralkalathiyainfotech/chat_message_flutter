import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/linked_devices_controller.dart';

class LinkedDeviceScannerScreen extends StatefulWidget {
  const LinkedDeviceScannerScreen({super.key});

  @override
  State<LinkedDeviceScannerScreen> createState() =>
      _LinkedDeviceScannerScreenState();
}

class _LinkedDeviceScannerScreenState extends State<LinkedDeviceScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  late final LinkedDevicesController linkedDevicesController =
      Get.isRegistered<LinkedDevicesController>()
      ? Get.find<LinkedDevicesController>()
      : Get.put(LinkedDevicesController());

  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!isProcessing) unawaited(_startScanner());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_stopScanner());
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(scannerController.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Linked devices',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.black,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scannerController,
            fit: BoxFit.cover,
            onDetect: _handleDetect,
          ),
          Container(color: Colors.black.withValues(alpha: 0.18)),
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: FractionallySizedBox(
                widthFactor: 0.82,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          if (isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (isProcessing) return;

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        rawValue = value;
        break;
      }
    }
    if (rawValue == null) return;

    setState(() => isProcessing = true);
    await _stopScanner();

    final linked = await linkedDevicesController.linkDeviceFromQr(rawValue);
    if (!mounted) return;

    if (linked) {
      Get.back(result: true);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => isProcessing = false);
    await _startScanner();
  }

  Future<void> _startScanner() async {
    try {
      await scannerController.start();
    } catch (error) {
      Get.log('Failed to start linked-device scanner: $error', isError: true);
    }
  }

  Future<void> _stopScanner() async {
    try {
      await scannerController.stop();
    } catch (error) {
      Get.log('Failed to stop linked-device scanner: $error', isError: true);
    }
  }
}
