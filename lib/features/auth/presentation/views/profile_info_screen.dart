import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../controllers/auth_controller.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/string_constants.dart';
import '../../../../core/routes/app_routes.dart';

class ProfileInfoScreen extends GetView<AuthController> {
  const ProfileInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundLight,
      appBar: AppBar(
        title: const Text(StringConstants.yourProfile, style: TextStyle(color: ColorConstants.white, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => Get.back()),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: ColorConstants.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                StringConstants.profileSubtitle,
                style: TextStyle(fontSize: 14, color: ColorConstants.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 40),
              Center(
                child: Obx(() => GestureDetector(
                  onTap: controller.pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFFD9D9D9),
                        backgroundImage: controller.selectedImage.value != null
                            ? FileImage(File(controller.selectedImage.value!.path))
                            : controller.existingPhotoUrl.value.isNotEmpty
                                ? NetworkImage(controller.existingPhotoUrl.value) as ImageProvider
                                : null,
                        child: (controller.selectedImage.value == null && controller.existingPhotoUrl.value.isEmpty)
                            ? const Icon(Icons.image, size: 50, color: ColorConstants.textSecondary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: ColorConstants.inputBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: ColorConstants.textSecondary, size: 20),
                        ),
                      ),
                    ],
                  ),
                )),
              ),
              const SizedBox(height: 40),
              const Text(StringConstants.fullNameLabel, style: TextStyle(color: ColorConstants.white, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: controller.userNameController,
                style: const TextStyle(color: ColorConstants.white),
                decoration: InputDecoration(
                  hintText: StringConstants.userNameHint,
                  hintStyle: const TextStyle(color: ColorConstants.textSecondary),
                  filled: true,
                  fillColor: ColorConstants.inputBackground,
                  suffixIcon: const Icon(Icons.sentiment_satisfied, color: ColorConstants.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(StringConstants.aboutLabel, style: TextStyle(color: ColorConstants.white, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: controller.bioController,
                maxLines: 4,
                style: const TextStyle(color: ColorConstants.white),
                decoration: InputDecoration(
                  hintText: StringConstants.bioHint,
                  hintStyle: const TextStyle(color: ColorConstants.textSecondary),
                  filled: true,
                  fillColor: ColorConstants.inputBackground,
                  suffixIcon: const Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 12.0, right: 12.0),
                        child: Icon(Icons.sentiment_satisfied, color: ColorConstants.textSecondary),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Obx(() => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value ? null : () => controller.updateProfile(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConstants.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: controller.isLoading.value 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: ColorConstants.white, strokeWidth: 2))
                    : const Text(StringConstants.save, style: TextStyle(color: ColorConstants.white, fontSize: 16)),
                ),
              )),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Get.offAllNamed(AppRoutes.home),
                  child: const Text(StringConstants.skip, style: TextStyle(color: ColorConstants.textSecondary, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
