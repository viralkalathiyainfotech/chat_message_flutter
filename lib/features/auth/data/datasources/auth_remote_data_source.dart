import 'package:chat_app/core/network/api_service.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import '../../../../constants/network_constants.dart';

abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String mobileNumber);
  Future<Map<String, dynamic>> verifyOtp(String mobileNumber, String otp);
  Future<UserModel> updateProfileInfo({required String userName, required String bio, XFile? photo});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiService apiService = Get.find<ApiService>();

  @override
  Future<void> sendOtp(String mobileNumber) async {
    final response = await apiService.dio.post(NetworkConstants.mobileOtp, data: {
      'mobileNumber': mobileNumber,
    });
    
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to send OTP',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(String mobileNumber, String otp) async {
    final response = await apiService.dio.post(NetworkConstants.verifyOtp, data: {
      'mobileNumber': mobileNumber,
      'otp': otp,
      'isMobile': true,
    });
    
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
  Future<UserModel> updateProfileInfo({required String userName, required String bio, XFile? photo}) async {
    FormData formData = FormData.fromMap({
      'userName': userName,
      'bio': bio,
    });

    if (photo != null) {
      formData.files.add(MapEntry(
        'photo',
        await MultipartFile.fromFile(photo.path, filename: photo.name),
      ));
    }

    final response = await apiService.dio.post(NetworkConstants.profileInfo, data: formData);
    
    if (response.statusCode == 200) {
      return UserModel.fromJson(response.data['user'] ?? response.data);
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to update profile info',
      );
    }
  }
}
