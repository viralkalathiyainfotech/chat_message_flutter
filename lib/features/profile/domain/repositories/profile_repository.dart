import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class ProfileRepository {
  Future<Either<Failure, void>> updateUserGroupToJoin(String groupToJoin);
  Future<Either<Failure, void>> updateUserProfilePhotoPrivacy(
    String profilePhoto,
  );
  Future<Either<Failure, void>> blockUser(String selectedUserId);
  Future<Either<Failure, List<dynamic>>> getContactUsers();
  Future<Either<Failure, void>> addContactList(List<Map<String, dynamic>> contacts);
  Future<Either<Failure, void>> qrLogin(Map<String, dynamic> qrData, Map<String, dynamic> deviceInfo);
  Future<Either<Failure, void>> editUser(String userId, String name, String bio, String? photoPath);
}
