import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../../../core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import '../../../../services/socket_service.dart';
import '../../domain/entities/user.dart';

class AuthController extends GetxController {
  final SendOtpUseCase sendOtpUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final UpdateProfileInfoUseCase updateProfileUseCase;
  final GetCurrentUserProfileUseCase getCurrentUserProfileUseCase;

  AuthController({
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.updateProfileUseCase,
    required this.getCurrentUserProfileUseCase,
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
  var isProfileLoading = false.obs;

  final ImagePicker _picker = ImagePicker();

  Future<void> loadLoggedInProfile() async {
    isProfileLoading.value = true;

    final result = await getCurrentUserProfileUseCase();

    isProfileLoading.value = false;
    result.fold((failure) {
      Get.log('Could not load existing profile info: ${failure.message}');
    }, _populateProfileFields);
  }

  Future<void> sendOtp() async {
    if (phoneController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter your phone number');
      return;
    }

    isLoading.value = true;
    mobileNumber.value = phoneController.text.trim();

    final result = await sendOtpUseCase("+91${mobileNumber.value}");

    isLoading.value = false;

    result.fold((failure) => Get.snackbar('Error', failure.message), (_) {
      Get.snackbar('Success', 'OTP sent successfully');
      Get.toNamed(AppRoutes.verifyOtp);
    });
  }

  Future<void> verifyOtp(String otp) async {
    isLoading.value = true;

    final result = await verifyOtpUseCase("+91${mobileNumber.value}", otp);

    isLoading.value = false;

    result.fold((failure) => Get.snackbar('Error', failure.message), (
      user,
    ) async {
      Get.snackbar('Success', 'OTP verified');
      await Get.find<SocketService>().ensureConnected();

      _populateProfileFields(user);

      // As requested by user: every time on login the profile update is required
      Get.offAllNamed(AppRoutes.profileInfo);
    });
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

    result.fold((failure) => Get.snackbar('Error', failure.message), (user) {
      _populateProfileFields(user);
      Get.offAllNamed(AppRoutes.home);
    });
  }

  void _populateProfileFields(User user) {
    userNameController.text = user.userName ?? '';
    bioController.text = user.bio ?? '';
    existingPhotoUrl.value = user.profilePhoto ?? '';
    selectedImage.value = null;
  }
}
