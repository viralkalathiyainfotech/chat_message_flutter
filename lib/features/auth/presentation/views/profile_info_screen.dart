import 'package:flutter/material.dart';
import 'package:get/get.dart' hide ContextExtensionss;
import 'dart:io';
import '../controllers/auth_controller.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/string_constants.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/extensions/app_extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final AuthController controller = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadLoggedInProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.backgroundDarkMode,
      appBar: AppBar(
        title: const Text(
          StringConstants.yourProfile,
          style: TextStyle(color: ColorConstants.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: context.back,
        ),
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
                'Review your profile details before continuing. Existing details are loaded from your account.',
                style: TextStyle(
                  fontSize: 14,
                  color: ColorConstants.textSecondary,
                  height: 1.5,
                ),
              ),
              Obx(
                () => controller.isProfileLoading.value
                    ? Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: ColorConstants.primaryBlue,
                          backgroundColor: ColorConstants.inputBackground,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              40.height,
              Center(
                child: Obx(
                  () => GestureDetector(
                    onTap: controller.pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFFD9D9D9),
                          backgroundImage:
                              controller.selectedImage.value != null
                              ? FileImage(
                                  File(controller.selectedImage.value!.path),
                                )
                              : controller.existingPhotoUrl.value.isNotEmpty
                              ? CachedNetworkImageProvider(
                                      controller.existingPhotoUrl.value,
                                    )
                                    as ImageProvider
                              : null,
                          child:
                              (controller.selectedImage.value == null &&
                                  controller.existingPhotoUrl.value.isEmpty)
                              ? const Icon(
                                  Icons.image,
                                  size: 50,
                                  color: ColorConstants.textSecondary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: 8.all,
                            decoration: const BoxDecoration(
                              color: ColorConstants.inputBackground,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: ColorConstants.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              40.height,
              const Text(
                StringConstants.fullNameLabel,
                style: TextStyle(color: ColorConstants.white, fontSize: 16),
              ),
              8.height,
              TextField(
                controller: controller.userNameController,
                style: const TextStyle(color: ColorConstants.white),
                decoration: InputDecoration(
                  hintText: StringConstants.userNameHint,
                  hintStyle: const TextStyle(
                    color: ColorConstants.textSecondary,
                  ),
                  filled: true,
                  fillColor: ColorConstants.inputBackground,
                  suffixIcon: const Icon(
                    Icons.sentiment_satisfied,
                    color: ColorConstants.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              30.height,
              const Text(
                StringConstants.aboutLabel,
                style: TextStyle(color: ColorConstants.white, fontSize: 16),
              ),
              8.height,
              TextField(
                controller: controller.bioController,
                maxLines: 4,
                style: const TextStyle(color: ColorConstants.white),
                decoration: InputDecoration(
                  hintText: StringConstants.bioHint,
                  hintStyle: const TextStyle(
                    color: ColorConstants.textSecondary,
                  ),
                  filled: true,
                  fillColor: ColorConstants.inputBackground,
                  suffixIcon: const Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 12.0, right: 12.0),
                        child: Icon(
                          Icons.sentiment_satisfied,
                          color: ColorConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              50.height,
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () => controller.updateProfile(),
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
                              StringConstants.save,
                              style: TextStyle(
                                color: ColorConstants.white,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              16.height,
              Center(
                child: TextButton(
                  onPressed: () => Get.offAllNamed(AppRoutes.home),
                  child: const Text(
                    StringConstants.skip,
                    style: TextStyle(
                      color: ColorConstants.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
