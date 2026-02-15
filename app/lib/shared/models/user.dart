import 'district.dart';

enum UserRole {
  client('CLIENT'),
  provider('PROVIDER'),
  admin('ADMIN');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.client,
    );
  }
}

class User {
  final String id;
  final String email;
  final UserRole role;
  final String fullName;
  final String phone;
  final String districtId;
  final District? district;
  final bool isVerified;
  final bool isBlocked;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.districtId,
    this.district,
    required this.isVerified,
    required this.isBlocked,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      districtId: json['district_id'] as String,
      district: json['district'] != null ? District.fromJson(json['district']) : null,
      isVerified: json['is_verified'] as bool,
      isBlocked: json['is_blocked'] as bool,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.value,
      'full_name': fullName,
      'phone': phone,
      'district_id': districtId,
      'is_verified': isVerified,
      'is_blocked': isBlocked,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
