class FaceMemberMatch {
  final int memberId;
  final String fullName;
  final int generation;
  final String gender;
  final String? avatarUrl;
  final double similarity;
  final String matchPercent;
  final String fatherName;
  final String motherName;
  final String branchName;

  FaceMemberMatch({
    required this.memberId,
    required this.fullName,
    required this.generation,
    required this.gender,
    this.avatarUrl,
    required this.similarity,
    required this.matchPercent,
    required this.fatherName,
    required this.motherName,
    required this.branchName,
  });

  factory FaceMemberMatch.fromJson(Map<String, dynamic> json) {
    return FaceMemberMatch(
      memberId: json['member_id'] ?? 0,
      fullName: json['full_name'] ?? '',
      generation: json['generation'] ?? 1,
      gender: json['gender'] ?? 'male',
      avatarUrl: json['avatar_url'],
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      matchPercent: json['match_percent'] ?? '0%',
      fatherName: json['father_name'] ?? 'Không rõ',
      motherName: json['mother_name'] ?? 'Không rõ',
      branchName: json['branch_name'] ?? 'Họ nội',
    );
  }
}

class FaceCandidate {
  final int faceIndex;
  final List<int> box;
  final String cropImageBase64;
  final List<double> embedding;

  FaceCandidate({
    required this.faceIndex,
    required this.box,
    required this.cropImageBase64,
    required this.embedding,
  });

  factory FaceCandidate.fromJson(Map<String, dynamic> json) {
    return FaceCandidate(
      faceIndex: json['face_index'] ?? 0,
      box: (json['box'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
      cropImageBase64: json['crop_image_base64'] ?? '',
      embedding: (json['embedding'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [],
    );
  }
}

class FaceSearchResult {
  final int faceIndex;
  final List<int> box;
  final String cropImageBase64;
  final List<FaceMemberMatch> matches;

  FaceSearchResult({
    required this.faceIndex,
    required this.box,
    required this.cropImageBase64,
    required this.matches,
  });

  factory FaceSearchResult.fromJson(Map<String, dynamic> json) {
    var rawMatches = json['matches'] as List<dynamic>? ?? [];
    return FaceSearchResult(
      faceIndex: json['face_index'] ?? 0,
      box: (json['box'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
      cropImageBase64: json['crop_image_base64'] ?? '',
      matches: rawMatches.map((m) => FaceMemberMatch.fromJson(m)).toList(),
    );
  }

  FaceMemberMatch? get bestMatch => matches.isNotEmpty ? matches.first : null;
}
