// models/user_model.dart
class UserModel {
  final String uid;
  final String username;
  final String profilePic;

  UserModel(
      {required this.uid, required this.username, required this.profilePic});

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      username: data['username'] ?? '',
      profilePic: data['profilePic'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'profilePic': profilePic,
    };
  }
}
