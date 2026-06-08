import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import 'package:image_picker/image_picker.dart';

class SendOtpUseCase {
  final AuthRepository repository;
  SendOtpUseCase(this.repository);

  Future<Either<Failure, void>> call(String mobileNumber) {
    return repository.sendOtp(mobileNumber);
  }
}

class VerifyOtpUseCase {
  final AuthRepository repository;
  VerifyOtpUseCase(this.repository);

  Future<Either<Failure, User>> call(String mobileNumber, String otp) {
    return repository.verifyOtp(mobileNumber, otp);
  }
}

class UpdateProfileInfoUseCase {
  final AuthRepository repository;
  UpdateProfileInfoUseCase(this.repository);

  Future<Either<Failure, User>> call(String userName, String bio, XFile? photo) {
    return repository.updateProfileInfo(userName: userName, bio: bio, photo: photo);
  }
}
