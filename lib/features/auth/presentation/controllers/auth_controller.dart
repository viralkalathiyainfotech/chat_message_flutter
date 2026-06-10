import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../../../core/routes/app_routes.dart';
import 'package:flutter/material.dart';

class AuthController extends GetxController {
  final SendOtpUseCase sendOtpUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final UpdateProfileInfoUseCase updateProfileUseCase;

  AuthController({
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.updateProfileUseCase,
  });

  var isLoading = false.obs;
  var mobileNumber = ''.obs;

  // Login
  final phoneController = TextEditingController();
  
  // OTP
  final otpController = TextEditingController();

  // Profile Info
  final userNameController = TextEditingController();
  final bioController = TextEditingController();
  var selectedImage = Rx<XFile?>(null);
  var existingPhotoUrl = ''.obs;

  final ImagePicker _picker = ImagePicker();

  Future<void> sendOtp() async {
    if (phoneController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter your phone number');
      return;
    }
    
    isLoading.value = true;
    mobileNumber.value = phoneController.text.trim();
    
    final result = await sendOtpUseCase("+91${mobileNumber.value}");
    
    isLoading.value = false;
    
    result.fold(
      (failure) => Get.snackbar('Error', failure.message),
      (_) {
        Get.snackbar('Success', 'OTP sent successfully');
        Get.toNamed(AppRoutes.verifyOtp);
      },
    );
  }

  Future<void> verifyOtp(String otp) async {
    isLoading.value = true;
    
    final result = await verifyOtpUseCase("+91${mobileNumber.value}", otp);
    
    isLoading.value = false;
    
    result.fold(
      (failure) => Get.snackbar('Error', failure.message),
      (user) {
        Get.snackbar('Success', 'OTP verified');
        
        // Populate existing profile details if any
        userNameController.text = user.userName ?? '';
        bioController.text = user.bio ?? '';
        existingPhotoUrl.value = user.profilePhoto ?? '';

        // As requested by user: every time on login the profile update is required
        Get.offAllNamed(AppRoutes.profileInfo);
      },
    );
  }

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedImage.value = image;
    }
  }

  Future<void> updateProfile() async {
    if (userNameController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter your user name');
      return;
    }

    isLoading.value = true;
    
    final result = await updateProfileUseCase(
      userNameController.text.trim(),
      bioController.text.trim(),
      selectedImage.value,
    );
    
    isLoading.value = false;
    
    result.fold(
      (failure) => Get.snackbar('Error', failure.message),
      (user) {
        Get.offAllNamed(AppRoutes.home);
      },
    );
  }
}
