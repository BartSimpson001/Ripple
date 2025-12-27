class UserModel {
  final String fullName;
  final String email;
  final String phone;
  final String uid;
  final String username;
  final DateTime createdAt;

  UserModel({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.uid,
    required this.username,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      uid: data['uid'] ?? '',
      username: data['username'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'uid': uid,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}