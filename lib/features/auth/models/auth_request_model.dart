import 'package:flutter/foundation.dart';

/// Model gửi yêu cầu Đăng nhập
@immutable
class LoginRequestModel {
  final String username;
  final String password;

  const LoginRequestModel({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) {
    return LoginRequestModel(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

/// Model gửi yêu cầu Đăng ký tài khoản
/// Tương thích với các trường trong cơ sở dữ liệu:
/// id, username, password_hash, first_name, last_name, gender, date_of_birth,
/// place_of_birth, email, cccd, avatar_url, role (mặc định 'member')
@immutable
class RegisterRequestModel {
  final String username;
  final String password;
  final String firstName;
  final String? lastName;
  final String? gender;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String email;
  final String? cccd;
  final String? avatarUrl;
  final String role; // Mặc định là 'member' và không cho phép thay đổi trên UI đăng ký

  const RegisterRequestModel({
    required this.username,
    required this.password,
    required this.firstName,
    this.lastName,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    required this.email,
    this.cccd,
    this.avatarUrl,
    this.role = 'member',
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'place_of_birth': placeOfBirth,
      'email': email,
      if (cccd != null && cccd!.isNotEmpty) 'cccd': cccd,
      if (avatarUrl != null && avatarUrl!.isNotEmpty) 'avatar_url': avatarUrl,
      'role': role,
    };
  }

  factory RegisterRequestModel.fromJson(Map<String, dynamic> json) {
    return RegisterRequestModel(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      firstName: json['first_name'] as String? ?? json['firstName'] as String? ?? '',
      lastName: json['last_name'] as String? ?? json['lastName'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String? ?? json['dateOfBirth'] as String?,
      placeOfBirth: json['place_of_birth'] as String? ?? json['placeOfBirth'] as String?,
      email: json['email'] as String? ?? '',
      cccd: json['cccd'] as String? ?? json['identityCard'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'member',
    );
  }
}

/// Model Người dùng (User) trả về từ hệ thống Auth
@immutable
class UserModel {
  final int? id;
  final String username;
  final String firstName;
  final String? lastName;
  final String? gender;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String email;
  final String? cccd;
  final String? avatarUrl;
  final String role;
  final String? createdAt;

  const UserModel({
    this.id,
    required this.username,
    required this.firstName,
    this.lastName,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    required this.email,
    this.cccd,
    this.avatarUrl,
    this.role = 'member',
    this.createdAt,
  });

  /// Họ và tên đầy đủ
  String get fullName {
    final last = lastName ?? '';
    final first = firstName;
    if (last.isEmpty) return first;
    return '$last $first'.trim();
  }

  /// Tên hiển thị
  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (username.isNotEmpty) return username;
    return 'Thành viên';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    int? parsedId;
    if (json['id'] != null) {
      parsedId = json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString());
    }

    return UserModel(
      id: parsedId,
      username: json['username'] as String? ?? '',
      firstName: json['first_name'] as String? ?? json['firstName'] as String? ?? '',
      lastName: json['last_name'] as String? ?? json['lastName'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String? ?? json['dateOfBirth'] as String?,
      placeOfBirth: json['place_of_birth'] as String? ?? json['placeOfBirth'] as String?,
      email: json['email'] as String? ?? '',
      cccd: json['cccd'] as String? ?? json['identityCard'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'member',
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'place_of_birth': placeOfBirth,
      'email': email,
      'cccd': cccd,
      'avatar_url': avatarUrl,
      'role': role,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? firstName,
    String? lastName,
    String? gender,
    String? dateOfBirth,
    String? placeOfBirth,
    String? email,
    String? cccd,
    String? avatarUrl,
    String? role,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      email: email ?? this.email,
      cccd: cccd ?? this.cccd,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Model phản hồi Auth từ Backend khi đăng nhập hoặc đăng ký thành công
@immutable
class AuthResponseModel {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? tokenType;
  final UserModel? user;

  const AuthResponseModel({
    this.success = true,
    this.message,
    this.accessToken,
    this.tokenType = 'bearer',
    this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    UserModel? parsedUser;
    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      parsedUser = UserModel.fromJson(json['user'] as Map<String, dynamic>);
    } else if (json['data'] != null && json['data'] is Map<String, dynamic>) {
      parsedUser = UserModel.fromJson(json['data'] as Map<String, dynamic>);
    }

    return AuthResponseModel(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
      accessToken: json['access_token'] as String? ?? json['token'] as String?,
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: parsedUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (message != null) 'message': message,
      if (accessToken != null) 'access_token': accessToken,
      if (tokenType != null) 'token_type': tokenType,
      if (user != null) 'user': user!.toJson(),
    };
  }
}
