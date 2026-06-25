import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/profile_repository.dart';

class UpdateUserGroupToJoinUseCase {
  final ProfileRepository repository;

  UpdateUserGroupToJoinUseCase(this.repository);

  Future<Either<Failure, void>> call(String groupToJoin) {
    return repository.updateUserGroupToJoin(groupToJoin);
  }
}

class UpdateUserProfilePhotoPrivacyUseCase {
  final ProfileRepository repository;

  UpdateUserProfilePhotoPrivacyUseCase(this.repository);

  Future<Either<Failure, void>> call(String profilePhoto) {
    return repository.updateUserProfilePhotoPrivacy(profilePhoto);
  }
}

class BlockUserUseCase {
  final ProfileRepository repository;

  BlockUserUseCase(this.repository);

  Future<Either<Failure, void>> call(String selectedUserId) {
    return repository.blockUser(selectedUserId);
  }
}

class GetContactUsersUseCase {
  final ProfileRepository repository;

  GetContactUsersUseCase(this.repository);

  Future<Either<Failure, List<dynamic>>> call() {
    return repository.getContactUsers();
  }
}

class AddContactListUseCase {
  final ProfileRepository repository;

  AddContactListUseCase(this.repository);

  Future<Either<Failure, void>> call(List<Map<String, dynamic>> contacts) {
    return repository.addContactList(contacts);
  }
}

class QrLoginUseCase {
  final ProfileRepository repository;

  QrLoginUseCase(this.repository);

  Future<Either<Failure, void>> call(Map<String, dynamic> qrData, Map<String, dynamic> deviceInfo) {
    return repository.qrLogin(qrData, deviceInfo);
  }
}

class EditUserUseCase {
  final ProfileRepository repository;

  EditUserUseCase(this.repository);

  Future<Either<Failure, void>> call(String userId, String name, String bio, String? photoPath) {
    return repository.editUser(userId, name, bio, photoPath);
  }
}
