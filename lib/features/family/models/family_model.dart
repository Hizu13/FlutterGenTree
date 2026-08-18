import 'package:flutter/foundation.dart';

/// Data Model đại diện cho một Dòng Họ / Gia Phả (Family)
/// Đồng bộ với bảng `families` trong MySQL:
/// id, name, description, origin_location, join_code, owner_id, created_at
@immutable
class FamilyModel {
  final int? id;
  final String name;
  final String? description;
  final String? originLocation;
  final String? joinCode;
  final int? ownerId;
  final String? createdAt;
  final String? userRole;
  final int memberCount;

  const FamilyModel({
    this.id,
    required this.name,
    this.description,
    this.originLocation,
    this.joinCode,
    this.ownerId,
    this.createdAt,
    this.userRole,
    this.memberCount = 0,
  });

  FamilyModel copyWith({
    int? id,
    String? name,
    String? description,
    String? originLocation,
    String? joinCode,
    int? ownerId,
    String? createdAt,
    String? userRole,
    int? memberCount,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      originLocation: originLocation ?? this.originLocation,
      joinCode: joinCode ?? this.joinCode,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      userRole: userRole ?? this.userRole,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'origin_location': originLocation,
      if (joinCode != null) 'join_code': joinCode,
      if (ownerId != null) 'owner_id': ownerId,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    int? parsedId;
    if (json['id'] != null) {
      parsedId = json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString());
    }

    int? parsedOwnerId;
    if (json['ownerId'] != null || json['owner_id'] != null) {
      final rawOwner = json['ownerId'] ?? json['owner_id'];
      parsedOwnerId = rawOwner is int
          ? rawOwner
          : int.tryParse(rawOwner.toString());
    }

    int parsedMemberCount = 0;
    if (json['memberCount'] != null || json['member_count'] != null) {
      final rawCount = json['memberCount'] ?? json['member_count'];
      parsedMemberCount = rawCount is int
          ? rawCount
          : (int.tryParse(rawCount.toString()) ?? 0);
    }

    return FamilyModel(
      id: parsedId,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      originLocation: json['originLocation'] as String? ??
          json['origin_location'] as String?,
      joinCode:
          json['joinCode'] as String? ?? json['join_code'] as String?,
      ownerId: parsedOwnerId,
      createdAt:
          json['createdAt'] as String? ?? json['created_at']?.toString(),
      userRole:
          json['userRole'] as String? ?? json['user_role'] as String?,
      memberCount: parsedMemberCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FamilyModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
