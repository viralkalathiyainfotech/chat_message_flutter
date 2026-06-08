import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/string_constants.dart';

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.person, color: Colors.black, size: 30)),
              ),
              const SizedBox(height: 24),
              const Text(
                StringConstants.welcomeBack,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ColorConstants.white),
              ),
              const SizedBox(height: 8),
              const Text(
                StringConstants.enterPhoneNumber,
                style: TextStyle(fontSize: 14, color: ColorConstants.textSecondary),
              ),
              const SizedBox(height: 40),
              const Text(
                StringConstants.countryLabel,
                style: TextStyle(color: ColorConstants.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                height: 55,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: ColorConstants.inputBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('India', style: TextStyle(color: ColorConstants.white, fontSize: 16))),
                    const Icon(Icons.keyboard_arrow_down, color: ColorConstants.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                StringConstants.mobileLabel,
                style: TextStyle(color: ColorConstants.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: ColorConstants.white),
                decoration: InputDecoration(
                  hintText: StringConstants.phoneNumberHint,
                  hintStyle: const TextStyle(color: ColorConstants.textSecondary),
                  filled: true,
                  fillColor: ColorConstants.inputBackground,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Text('+91', style: TextStyle(color: ColorConstants.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Obx(() => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value ? null : () => controller.sendOtp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConstants.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: controller.isLoading.value 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: ColorConstants.white, strokeWidth: 2))
                      : const Text(StringConstants.continueBtn, style: TextStyle(color: ColorConstants.white, fontSize: 16)),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
