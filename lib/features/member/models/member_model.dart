import 'package:flutter/foundation.dart';
import '../../../config/api_config.dart';

/// Data Model đại diện cho thông tin một Thành Viên trong Gia Phả.
@immutable
class MemberModel {
  final String? id;
  final int? userId;
  final int? familyId;
  final String fullName;
  final String gender; // 'Nam' | 'Nữ' | 'Khác'
  final String role; // 'admin' | 'editor' | 'member'
  final String status; // 'Còn sống' | 'Đã mất'
  final String? dateOfBirth; // Định dạng dd/MM/yyyy
  final String? placeOfBirth;
  final String? fatherId;
  final String? fatherName;
  final String? motherId;
  final String? motherName;
  final String? phoneNumber;
  final String? email;
  final String? currentAddress;
  final String? permanentAddress;
  final String? dateOfDeath; // Định dạng dd/MM/yyyy
  final String? placeOfDeath;
  final String? occupation;
  final String? notes; // Tiểu sử / Ghi chú (biography / notes)
  final String? avatarUrl;
  final int? generation; // Đời thứ mấy
  final String? identityCard; // Số CCCD / CMND
  final String? createdAt; // Thời gian tạo bản ghi


  const MemberModel({
    this.id,
    this.userId,
    this.familyId,
    required this.fullName,
    required this.gender,
    this.role = 'member',
    this.status = 'Còn sống',
    this.dateOfBirth,
    this.placeOfBirth,
    this.fatherId,
    this.fatherName,
    this.motherId,
    this.motherName,
    this.phoneNumber,
    this.email,
    this.currentAddress,
    this.permanentAddress,
    this.dateOfDeath,
    this.placeOfDeath,
    this.occupation,
    this.notes,
    this.avatarUrl,
    this.generation,
    this.identityCard,
    this.createdAt,
  });
  /// Kiểm tra thành viên còn sống hay không
  bool get isAlive => status == 'Còn sống' && (dateOfDeath == null || dateOfDeath!.isEmpty);

  /// Mã giới tính chuẩn hóa lưu vào database backend ('male', 'female', 'other')
  String get dbGender {
    switch (gender) {
      case 'Nam':
        return 'male';
      case 'Nữ':
        return 'female';
      case 'Khác':
      default:
        return gender == 'female' ? 'female' : (gender == 'male' ? 'male' : 'other');
    }
  }

  /// Năm sinh được trích xuất từ dateOfBirth
  String get birthYear {
    if (dateOfBirth == null || dateOfBirth!.isEmpty) return 'N/A';
    final parts = dateOfBirth!.split('/');
    if (parts.length == 3) return parts[2];
    final match = RegExp(r'\d{4}').firstMatch(dateOfBirth!);
    return match?.group(0) ?? 'N/A';
  }

  MemberModel copyWith({
    String? id,
    int? userId,
    int? familyId,
    String? fullName,
    String? gender,
    String? role,
    String? status,
    String? dateOfBirth,
    String? placeOfBirth,
    String? fatherId,
    String? fatherName,
    String? motherId,
    String? motherName,
    String? phoneNumber,
    String? email,
    String? currentAddress,
    String? permanentAddress,
    String? dateOfDeath,
    String? placeOfDeath,
    String? occupation,
    String? notes,
    String? avatarUrl,
    int? generation,
    String? identityCard,
    String? createdAt,
  }) {
    return MemberModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      familyId: familyId ?? this.familyId,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      status: status ?? this.status,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      fatherId: fatherId ?? this.fatherId,
      fatherName: fatherName ?? this.fatherName,
      motherId: motherId ?? this.motherId,
      motherName: motherName ?? this.motherName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      currentAddress: currentAddress ?? this.currentAddress,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      dateOfDeath: dateOfDeath ?? this.dateOfDeath,
      placeOfDeath: placeOfDeath ?? this.placeOfDeath,
      occupation: occupation ?? this.occupation,
      notes: notes ?? this.notes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      generation: generation ?? this.generation,
      identityCard: identityCard ?? this.identityCard,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String? get resolvedAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://')) {
      return avatarUrl!;
    }
    final base = Uri.parse(ApiConfig.baseUrl).origin;
    return '$base$avatarUrl';
  }

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'userId': userId,
      if (familyId != null) 'familyId': familyId,
      'fullName': fullName,
      'gender': gender,
      'role': role,
      'status': status,
      'dateOfBirth': dateOfBirth,
      'placeOfBirth': placeOfBirth,
      'fatherId': fatherId,
      'fatherName': fatherName,
      'motherId': motherId,
      'motherName': motherName,
      'phoneNumber': phoneNumber,
      'email': email,
      'currentAddress': currentAddress,
      'permanentAddress': permanentAddress,
      'dateOfDeath': dateOfDeath,
      'placeOfDeath': placeOfDeath,
      'occupation': occupation,
      'notes': notes,
      'avatarUrl': avatarUrl,
      'generation': generation,
      'identityCard': identityCard,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  factory MemberModel.fromJson(Map<String, dynamic> json) {
        // Xử lý họ tên đầy đủ
    String parsedFullName = json['fullName'] as String? ?? json['full_name'] as String? ?? '';
    if (parsedFullName.isEmpty && (json['first_name'] != null || json['last_name'] != null)) {
      final last = json['last_name'] as String? ?? '';
      final first = json['first_name'] as String? ?? '';
      parsedFullName = '$last $first'.trim();
    }

    // Chuẩn hóa giới tính: male -> Nam, female -> Nữ, other -> Khác
    String rawGender = json['gender'] as String? ?? 'Nam';
    String parsedGender = rawGender;
    if (rawGender.toLowerCase() == 'male') {
      parsedGender = 'Nam';
    } else if (rawGender.toLowerCase() == 'female') {
      parsedGender = 'Nữ';
    } else if (rawGender.toLowerCase() == 'other') {
      parsedGender = 'Khác';
    }

    // Xử lý userId
    int? parsedUserId;
    if (json['userId'] != null) {
      parsedUserId = json['userId'] is int
          ? json['userId'] as int
          : int.tryParse(json['userId'].toString());
    } else if (json['user_id'] != null) {
      parsedUserId = json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id'].toString());
    }

    // Xử lý familyId
    int? parsedFamilyId;
    if (json['familyId'] != null) {
      parsedFamilyId = json['familyId'] is int
          ? json['familyId'] as int
          : int.tryParse(json['familyId'].toString());
    } else if (json['family_id'] != null) {
      parsedFamilyId = json['family_id'] is int
          ? json['family_id'] as int
          : int.tryParse(json['family_id'].toString());
    }

    // Xử lý status
    final dateOfDeathStr = json['dateOfDeath'] as String? ?? json['date_of_death'] as String?;
    String parsedStatus = json['status'] as String? ??
        ((dateOfDeathStr != null && dateOfDeathStr.isNotEmpty) ? 'Đã mất' : 'Còn sống');

    // Xử lý generation
    int? parsedGeneration;
    if (json['generation'] != null) {
      parsedGeneration = json['generation'] is int
          ? json['generation'] as int
          : int.tryParse(json['generation'].toString());
    }

    return MemberModel(
      id: json['id']?.toString(),
      userId: parsedUserId,
      familyId: parsedFamilyId,
      fullName: parsedFullName,
      gender: parsedGender,
      role: json['role'] as String? ?? 'member',
      status: parsedStatus,
      dateOfBirth: json['dateOfBirth'] as String? ?? json['date_of_birth'] as String?,
      placeOfBirth: json['placeOfBirth'] as String? ?? json['place_of_birth'] as String?,
      fatherId: json['fatherId']?.toString() ?? json['father_id']?.toString(),
      fatherName: json['fatherName'] as String? ?? json['father_name'] as String?,
      motherId: json['motherId']?.toString() ?? json['mother_id']?.toString(),
      motherName: json['motherName'] as String? ?? json['mother_name'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? json['phone_number'] as String?,
      email: json['email'] as String?,
      currentAddress: json['currentAddress'] as String? ?? json['current_address'] as String?,
      permanentAddress: json['permanentAddress'] as String? ?? json['permanent_address'] as String?,
      dateOfDeath: dateOfDeathStr,
      placeOfDeath: json['placeOfDeath'] as String? ?? json['place_of_death'] as String?,
      occupation: json['occupation'] as String?,
      notes: json['notes'] as String? ?? json['biography'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      generation: parsedGeneration,
      identityCard: json['identityCard'] as String? ?? json['cccd'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at']?.toString(),
    );
  }
    @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
