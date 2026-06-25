import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../../core/error/failures.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/storage_service.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ConnectivityService connectivity = Get.find<ConnectivityService>();
  final StorageService storageService = Get.find<StorageService>();

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> updateUserGroupToJoin(
    String groupToJoin,
  ) async {
    if (!connectivity.isOnline.value) {
      return Left(ServerFailure('No internet connection'));
    }
    try {
      final userId = storageService.getUserId();
      if (userId == null || userId.isEmpty) {
        return Left(ServerFailure('User not logged in'));
      }
      await remoteDataSource.updateUserGroupToJoin(userId, groupToJoin);
      await storageService.saveString('privacy_group_to_join', groupToJoin);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['message'] ?? e.error?.toString() ?? 'Server error',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserProfilePhotoPrivacy(
    String profilePhoto,
  ) async {
    if (!connectivity.isOnline.value) {
      return Left(ServerFailure('No internet connection'));
    }
    try {
      final userId = storageService.getUserId();
      if (userId == null || userId.isEmpty) {
        return Left(ServerFailure('User not logged in'));
      }
      await remoteDataSource.updateUserProfilePhotoPrivacy(
        userId,
        profilePhoto,
      );
      await storageService.saveString('privacy_profile_photo', profilePhoto);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['message'] ?? e.error?.toString() ?? 'Server error',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> blockUser(String selectedUserId) async {
    if (!connectivity.isOnline.value) {
      return Left(ServerFailure('No internet connection'));
    }
    try {
      await remoteDataSource.blockUser(selectedUserId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['message'] ?? e.error?.toString() ?? 'Server error',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<dynamic>>> getContactUsers() async {
    if (!connectivity.isOnline.value) {
      return Left(ServerFailure('No internet connection'));
    }
    try {
      final users = await remoteDataSource.getContactUsers();
      return Right(users);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['message'] ?? e.error?.toString() ?? 'Server error',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addContactList(List<Map<String, dynamic>> contacts) async {
    if (!connectivity.isOnline.value) {
      return Left(ServerFailure('No internet connection'));
    }
    try {
      await remoteDataSource.addContactList(contacts);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['message'] ?? e.error?.toString() ?? 'Server error',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> qrLogin(Map<String, dynamic> qrData, Map<String, dynamic> deviceInfo) async {
    if (!connectivity.isOnline.value) {
      return Left(ServerFailure('No internet connection'));
    }
    try {
      await remoteDataSource.qrLogin(qrData, deviceInfo);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['message'] ?? e.error?.toString() ?? 'Server error',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> editUser(String userId, String name, String bio, String? photoPath) async {
    if (!connectivity.isOnline.value) {
      return Left(ServerFailure('No internet connection'));
    }
    try {
      await remoteDataSource.editUser(userId, name, bio, photoPath);
      return const Right(null);
    } on DioException catch (e) {
      return Left(
        ServerFailure(
          e.response?.data?['message'] ?? e.error?.toString() ?? 'Server error',
        ),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
