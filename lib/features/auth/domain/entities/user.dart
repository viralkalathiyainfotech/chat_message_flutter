// domain/entities/user.dart
class User {
  final String id;
  final String mobileNumber;
  final String? userName;
  final String? bio;
  final String? profilePhoto;

  User({
    required this.id,
    required this.mobileNumber,
    this.userName,
    this.bio,
    this.profilePhoto,
  });
}
