import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import 'package:image_picker/image_picker.dart';

abstract class AuthRepository {
  Future<Either<Failure, void>> sendOtp(String mobileNumber);
  Future<Either<Failure, User>> verifyOtp(String mobileNumber, String otp);
  Future<Either<Failure, User>> updateProfileInfo({
    required String userName,
    required String bio,
    XFile? photo,
  });
}
