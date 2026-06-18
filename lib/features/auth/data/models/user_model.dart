import '../../domain/entities/user.dart';

class UserModel extends User {
  UserModel({
    required super.id,
    required super.mobileNumber,
    super.userName,
    super.bio,
    super.profilePhoto,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      userName: json['userName'],
      bio: json['bio'],
      profilePhoto: json['photo'] ?? json['profilePhoto'],
    );
  }
}
