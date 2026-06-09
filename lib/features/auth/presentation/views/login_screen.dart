import 'package:flutter/material.dart';
import 'package:get/get.dart' hide ContextExtensionss;
import '../controllers/auth_controller.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/string_constants.dart';
import '../../../../core/extensions/app_extensions.dart';

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundDarkMode,
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
              24.height,
              const Text(
                StringConstants.welcomeBack,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ColorConstants.white),
              ),
              8.height,
              const Text(
                StringConstants.enterPhoneNumber,
                style: TextStyle(fontSize: 14, color: ColorConstants.textSecondary),
              ),
              40.height,
              const Text(
                StringConstants.countryLabel,
                style: TextStyle(color: ColorConstants.white, fontSize: 16),
              ),
              8.height,
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
                    12.width,
                    const Expanded(child: Text('India', style: TextStyle(color: ColorConstants.white, fontSize: 16))),
                    const Icon(Icons.keyboard_arrow_down, color: ColorConstants.textSecondary),
                  ],
                ),
              ),
              24.height,
              const Text(
                StringConstants.mobileLabel,
                style: TextStyle(color: ColorConstants.white, fontSize: 16),
              ),
              8.height,
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
              40.height,
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
