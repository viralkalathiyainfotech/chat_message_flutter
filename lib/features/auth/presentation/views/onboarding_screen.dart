import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/string_constants.dart';
import '../../../../constants/asset_constants.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Placeholder for the onboarding image
              Image.asset(
                AssetConstants.onboardingBackground, 
                height: 350, 
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 150, color: ColorConstants.textSecondary),
              ),
              const SizedBox(height: 40),
              const Text(
                StringConstants.onboardingTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: ColorConstants.white),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    StringConstants.secureMessaging,
                    style: const TextStyle(color: ColorConstants.textSecondary, fontSize: 16),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.offAllNamed(AppRoutes.login),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: ColorConstants.primaryBlue, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward, color: Colors.white),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            StringConstants.startMessaging, 
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                      const SizedBox(width: 60), // To perfectly center the text
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
