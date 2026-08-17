import 'package:flutter/foundation.dart';
import '../../../config/api_config.dart';

/// Data Model đại diện cho thông tin một Thành Viên trong Gia Phả.
@immutable
class MemberModel {
  final String? id;
  final String fullName;
  final String gender; // 'Nam' | 'Nữ'
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
  final String? dateOfDeath; // Định dạng dd/MM/yyyy
  final String? placeOfDeath;
  final String? occupation;
  final String? notes;
  final String? avatarUrl;
  final int? generation; // Đời thứ mấy
  final String? identityCard; // Số Căn cước công dân


  const MemberModel({
    this.id,
    required this.fullName,
    required this.gender,
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
    this.dateOfDeath,
    this.placeOfDeath,
    this.occupation,
    this.notes,
    this.avatarUrl,
    this.generation,
    this.identityCard,

  });

  MemberModel copyWith({
    String? id,
    String? fullName,
    String? gender,
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
    String? dateOfDeath,
    String? placeOfDeath,
    String? occupation,
    String? notes,
    String? avatarUrl,
    int? generation,
    String? identityCard,

  }) {
    return MemberModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
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
      dateOfDeath: dateOfDeath ?? this.dateOfDeath,
      placeOfDeath: placeOfDeath ?? this.placeOfDeath,
      occupation: occupation ?? this.occupation,
      notes: notes ?? this.notes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      generation: generation ?? this.generation,
      identityCard: identityCard ?? this.identityCard,

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
      'fullName': fullName,
      'gender': gender,
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
      'dateOfDeath': dateOfDeath,
      'placeOfDeath': placeOfDeath,
      'occupation': occupation,
      'notes': notes,
      'avatarUrl': avatarUrl,
      'generation': generation,
      'identityCard': identityCard,

    };
  }

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] as String?,
      fullName: json['fullName'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Nam',
      status: json['status'] as String? ?? 'Còn sống',
      dateOfBirth: json['dateOfBirth'] as String?,
      placeOfBirth: json['placeOfBirth'] as String?,
      fatherId: json['fatherId'] as String?,
      fatherName: json['fatherName'] as String?,
      motherId: json['motherId'] as String?,
      motherName: json['motherName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      currentAddress: json['currentAddress'] as String?,
      dateOfDeath: json['dateOfDeath'] as String?,
      placeOfDeath: json['placeOfDeath'] as String?,
      occupation: json['occupation'] as String?,
      notes: json['notes'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      generation: json['generation'] as int?,
      identityCard: json['identityCard'] as String?,

    );
  }
}
