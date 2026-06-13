// lib/sdk/models/app_user_model.dart

class AppUserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final String? bloodGroup;
  final String? fcmToken;
  final String? deviceType;
  final Map<String, dynamic> raw;

  const AppUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.bloodGroup,
    this.fcmToken,
    this.deviceType,
    required this.raw,
  });

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      bloodGroup: map['blood_group']?.toString(),
      fcmToken: map['fcm_token']?.toString(),
      deviceType: map['device_type']?.toString(),
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...raw,
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'blood_group': bloodGroup,
      'fcm_token': fcmToken,
      'device_type': deviceType,
    };
  }
}