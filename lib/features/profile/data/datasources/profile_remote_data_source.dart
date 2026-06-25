import 'package:dio/dio.dart';
import 'package:get/get.dart' hide MultipartFile, FormData;
import '../../../../constants/network_constants.dart';
import '../../../../core/network/api_service.dart';

abstract class ProfileRemoteDataSource {
  Future<void> updateUserGroupToJoin(String userId, String groupToJoin);
  Future<void> updateUserProfilePhotoPrivacy(
    String userId,
    String profilePhoto,
  );
  Future<void> blockUser(String selectedUserId);
  Future<List<dynamic>> getContactUsers();
  Future<void> addContactList(List<Map<String, dynamic>> contacts);
  Future<void> qrLogin(Map<String, dynamic> qrData, Map<String, dynamic> deviceInfo);
  Future<void> editUser(String userId, String name, String bio, String? photoPath);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiService apiService = Get.find<ApiService>();

  @override
  Future<void> updateUserGroupToJoin(String userId, String groupToJoin) async {
    final response = await apiService.dio.post(
      NetworkConstants.updateUserGroupToJoin(userId),
      data: {'groupToJoin': groupToJoin},
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to update group invitation privacy',
      );
    }
  }

  @override
  Future<void> updateUserProfilePhotoPrivacy(
    String userId,
    String profilePhoto,
  ) async {
    final response = await apiService.dio.post(
      NetworkConstants.updateUserProfilePhotoPrivacy(userId),
      data: {'profilePhoto': profilePhoto},
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to update profile photo privacy',
      );
    }
  }

  @override
  Future<void> blockUser(String selectedUserId) async {
    final response = await apiService.dio.post(
      NetworkConstants.blockUser,
      data: {'selectedUserId': selectedUserId},
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to block/unblock user',
      );
    }
  }

  @override
  Future<List<dynamic>> getContactUsers() async {
    final response = await apiService.dio.get(
      NetworkConstants.allContactUsers,
    );
    if (response.statusCode == 200) {
      return response.data['users'] ?? [];
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to fetch contact users',
      );
    }
  }

  @override
  Future<void> addContactList(List<Map<String, dynamic>> contacts) async {
    final response = await apiService.dio.post(
      NetworkConstants.addContactList,
      data: {'contacts': contacts},
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to add contact list',
      );
    }
  }

  @override
  Future<void> qrLogin(Map<String, dynamic> qrData, Map<String, dynamic> deviceInfo) async {
    final response = await apiService.dio.post(
      NetworkConstants.qrLogin,
      data: {
        'qrData': qrData,
        'deviceInfo': deviceInfo,
      },
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: response.data?['message'] ?? 'Failed to perform QR login',
      );
    }
  }

  @override
  Future<void> editUser(String userId, String name, String bio, String? photoPath) async {
    final Map<String, dynamic> data = {
      'userName': name,
      'bio': bio,
    };
    if (photoPath != null && photoPath.isNotEmpty) {
      data['photo'] = await MultipartFile.fromFile(photoPath);
    }
    final formData = FormData.fromMap(data);
    final response = await apiService.dio.put(
      NetworkConstants.editUser(userId),
      data: formData,
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to update user profile',
      );
    }
  }
}
