import 'package:chat_app/core/network/api_service.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import '../../../../constants/network_constants.dart';
import '../../../../services/storage_service.dart';

abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String mobileNumber);
  Future<Map<String, dynamic>> verifyOtp(String mobileNumber, String otp);
  Future<UserModel> getCurrentUserProfile();
  Future<UserModel> updateProfileInfo({
    required String userName,
    required String bio,
    XFile? photo,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiService apiService = Get.find<ApiService>();
  final StorageService storageService = Get.find<StorageService>();

  @override
  Future<void> sendOtp(String mobileNumber) async {
    final response = await apiService.dio.post(
      NetworkConstants.mobileOtp,
      data: {'mobileNumber': mobileNumber},
    );

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to send OTP',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String mobileNumber,
    String otp,
  ) async {
    final response = await apiService.dio.post(
      NetworkConstants.verifyOtp,
      data: {'mobileNumber': mobileNumber, 'otp': otp, 'isMobile': true},
    );

    if (response.statusCode == 200) {
      return {
        'user': UserModel.fromJson(response.data['user']),
        'token': response.data['token'],
        'refreshToken': response.data['refreshToken'],
      };
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to verify OTP',
      );
    }
  }

  @override
  Future<UserModel> getCurrentUserProfile() async {
    final userId = storageService.getUserId();
    if (userId == null || userId.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: NetworkConstants.allUsers),
        error: 'User id not available',
      );
    }

    final response = await apiService.dio.get(
      NetworkConstants.singleUser(userId),
    );

    if (response.statusCode == 200) {
      final data =
          response.data['user'] ??
          response.data['users'] ??
          response.data['data'] ??
          response.data;
      return UserModel.fromJson(data);
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to load profile info',
      );
    }
  }

  @override
  Future<UserModel> updateProfileInfo({
    required String userName,
    required String bio,
    XFile? photo,
  }) async {
    FormData formData = FormData.fromMap({'userName': userName, 'bio': bio});

    if (photo != null) {
      formData.files.add(
        MapEntry(
          'photo',
          await MultipartFile.fromFile(photo.path, filename: photo.name),
        ),
      );
    }

    final userId = storageService.getUserId();
    final response = (userId != null && userId.isNotEmpty)
        ? await apiService.dio.put(
            NetworkConstants.editUser(userId),
            data: formData,
          )
        : await apiService.dio.post(
            NetworkConstants.profileInfo,
            data: formData,
          );

    if (response.statusCode == 200) {
      return UserModel.fromJson(
        response.data['user'] ?? response.data['users'] ?? response.data,
      );
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to update profile info',
      );
    }
  }
}
