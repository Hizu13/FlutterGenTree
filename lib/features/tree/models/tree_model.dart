import '../../member/models/member_model.dart';

class TreeNode {
  final String id;
  final String name;
  final String gender;
  final String birthYear;
  final String? dob;
  final String? avatarUrl;
  final List<String> spouses;
  final String? fatherId;
  final String? motherId;

  TreeNode({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthYear,
    this.dob,
    this.avatarUrl,
    this.spouses = const [],
    this.fatherId,
    this.motherId,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? "Không tên",
      gender: json['gender'] ?? "Nam",
      birthYear: json['birth_year']?.toString() ?? "N/A",
      dob: json['dob']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      spouses: (json['spouses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fatherId: json['father_id']?.toString(),
      motherId: json['mother_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'birth_year': birthYear,
      'dob': dob,
      'avatar_url': avatarUrl,
      'spouses': spouses,
      'father_id': fatherId,
      'mother_id': motherId,
    };
  }
}

class TreeEdge {
  final String fromId;
  final String toId;
  final String type;

  TreeEdge({
    required this.fromId,
    required this.toId,
    required this.type,
  });

  factory TreeEdge.fromJson(Map<String, dynamic> json) {
    return TreeEdge(
      fromId: json['from_id']?.toString() ?? '',
      toId: json['to_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_id': fromId,
      'to_id': toId,
      'type': type,
    };
  }
}

class TreeResponse {
  final List<TreeNode> nodes;
  final List<TreeEdge> edges;

  TreeResponse({required this.nodes, required this.edges});

  factory TreeResponse.fromJson(Map<String, dynamic> json) {
    return TreeResponse(
      nodes: (json['nodes'] as List? ?? []).map((e) => TreeNode.fromJson(e)).toList(),
      edges: (json['edges'] as List? ?? []).map((e) => TreeEdge.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((e) => e.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    };
  }

  /// Hàm tĩnh để chuyển đổi danh sách MemberModel thành TreeResponse
  static TreeResponse fromMemberList(List<MemberModel> members) {
    final List<TreeNode> nodes = [];
    final List<TreeEdge> edges = [];

    // Duyệt qua tất cả các thành viên để tạo Node và mối quan hệ
    for (final member in members) {
      if (member.id == null) continue;

      // Tính toán danh sách vợ/chồng (spouses) cho thành viên hiện tại
      final List<String> spouses = [];
      
      // Tìm vợ/chồng của member bằng cách tìm các con mà cha/mẹ chính là member này
      final children = members.where((m) => m.fatherId == member.id || m.motherId == member.id);
      for (final child in children) {
        if (member.gender == 'Nam' && child.motherId != null) {
          if (!spouses.contains(child.motherId!)) {
            spouses.add(child.motherId!);
          }
        } else if (member.gender == 'Nữ' && child.fatherId != null) {
          if (!spouses.contains(child.fatherId!)) {
            spouses.add(child.fatherId!);
          }
        }
      }

      // Lấy năm sinh
      String birthYear = 'N/A';
      if (member.dateOfBirth != null && member.dateOfBirth!.isNotEmpty) {
        final parts = member.dateOfBirth!.split('/');
        if (parts.length == 3) {
          birthYear = parts[2];
        } else {
          // Fallback if not dd/MM/yyyy
          final match = RegExp(r'\d{4}').firstMatch(member.dateOfBirth!);
          if (match != null) {
            birthYear = match.group(0)!;
          }
        }
      }

      nodes.add(TreeNode(
        id: member.id!,
        name: member.fullName,
        gender: member.gender,
        birthYear: birthYear,
        dob: member.dateOfBirth,
        avatarUrl: member.avatarUrl,
        spouses: spouses,
        fatherId: member.fatherId,
        motherId: member.motherId,
      ));

      // Tạo các cạnh (edges) kết nối cha -> con, mẹ -> con
      if (member.fatherId != null) {
        edges.add(TreeEdge(
          fromId: member.fatherId!,
          toId: member.id!,
          type: 'parent-child',
        ));
      }
      if (member.motherId != null) {
        edges.add(TreeEdge(
          fromId: member.motherId!,
          toId: member.id!,
          type: 'parent-child',
        ));
      }
      // Tạo cạnh kết nối vợ chồng
      for (final spouseId in spouses) {
        // Chỉ thêm 1 chiều để tránh lặp cạnh kết nối (vợ - chồng)
        if (member.id!.compareTo(spouseId) < 0) {
          edges.add(TreeEdge(
            fromId: member.id!,
            toId: spouseId,
            type: 'spouse',
          ));
        }
      }
    }

    return TreeResponse(nodes: nodes, edges: edges);
  }
}

class TreeRelationship {
  final String fromId; // ID người cha/mẹ
  final String toId;   // ID người con

  TreeRelationship({required this.fromId, required this.toId});
}
