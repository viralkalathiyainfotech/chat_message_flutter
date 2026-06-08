import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/storage_service.dart';
import 'package:get/get.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final StorageService storageService = Get.find<StorageService>();

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, void>> sendOtp(String mobileNumber) async {
    try {
      await remoteDataSource.sendOtp(mobileNumber);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to send OTP'));
    } catch (e) {
      return Left(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, User>> verifyOtp(String mobileNumber, String otp) async {
    try {
      final result = await remoteDataSource.verifyOtp(mobileNumber, otp);
      
      // Save tokens
      await storageService.saveTokens(
        token: result['token'],
        refreshToken: result['refreshToken'],
      );
      
      return Right(result['user'] as User);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to verify OTP'));
    } catch (e) {
      return Left(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfileInfo({
    required String userName,
    required String bio,
    XFile? photo,
  }) async {
    try {
      final user = await remoteDataSource.updateProfileInfo(
        userName: userName,
        bio: bio,
        photo: photo,
      );
      return Right(user);
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Failed to update profile info'));
    } catch (e) {
      return Left(ServerFailure('An unexpected error occurred'));
    }
  }
}
