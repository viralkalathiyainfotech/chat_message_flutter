import 'package:flutter/material.dart';
import 'package:get/get.dart' hide ContextExtensionss;
import 'package:pinput/pinput.dart';
import '../controllers/auth_controller.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/string_constants.dart';
import '../../../../core/extensions/app_extensions.dart';

class VerifyOtpScreen extends GetView<AuthController> {
  const VerifyOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundDarkMode,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: context.back,
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: ColorConstants.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              20.height,
              const Text(
                StringConstants.verifyOtpTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ColorConstants.white,
                ),
              ),
              12.height,
              Obx(
                () => RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: ColorConstants.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: '${StringConstants.smsSentTo} '),
                      TextSpan(
                        text: '+91 ${controller.mobileNumber.value}\n',
                        style: const TextStyle(
                          color: ColorConstants.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: StringConstants.pleaseEnterToVerify),
                    ],
                  ),
                ),
              ),
              40.height,
              Pinput(
                length: 6,
                controller: controller.otpController,
                defaultPinTheme: PinTheme(
                  width: 50,
                  height: 55,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    color: ColorConstants.white,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: ColorConstants.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onCompleted: (pin) => controller.verifyOtp(pin),
              ),
              40.height,
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () {
                            if (controller.otpController.text.length == 6) {
                              controller.verifyOtp(
                                controller.otpController.text,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConstants.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: controller.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: ColorConstants.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              StringConstants.verifyOtpTitle,
                              style: TextStyle(
                                color: ColorConstants.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              24.height,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    StringConstants.didntReceive,
                    style: TextStyle(
                      color: ColorConstants.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  4.width,
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      StringConstants.resendCode,
                      style: TextStyle(
                        color: ColorConstants.primaryBlue,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: ColorConstants.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
