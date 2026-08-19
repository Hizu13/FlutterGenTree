import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../config/api_config.dart';
import '../../auth/services/auth_service.dart';

class AdminDashboardStats {
  final int familyId;
  final String familyName;
  final int totalMembers;
  final int pendingApprovals;
  final int pendingTransactions;
  final int pendingEvents;
  final int pendingMembers;
  final int newJoins;
  final double totalBalance;
  final String formattedBalance;

  AdminDashboardStats({
    required this.familyId,
    required this.familyName,
    required this.totalMembers,
    required this.pendingApprovals,
    required this.pendingTransactions,
    required this.pendingEvents,    
    required this.pendingMembers,
    required this.newJoins,
    required this.totalBalance,
    required this.formattedBalance,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      familyId: json['family_id'] ?? 0,
      familyName: json['family_name'] ?? '',
      totalMembers: json['total_members'] ?? 0,
      pendingApprovals: json['pending_approvals'] ?? 0,
      pendingTransactions: json['pending_transactions'] ?? 0,
      pendingEvents: json['pending_events'] ?? 0,
      pendingMembers: json['pending_members'] ?? (json['new_joins'] ?? 0),
      newJoins: json['new_joins'] ?? 0,
      totalBalance: (json['total_balance'] as num?)?.toDouble() ?? 0.0,
      formattedBalance: json['formatted_balance'] ?? '0 đ',
    );
  }

  factory AdminDashboardStats.empty() {
    return AdminDashboardStats(
      familyId: 0,
      familyName: '',
      totalMembers: 0,
      pendingApprovals: 0,
      pendingTransactions: 0,
      pendingEvents: 0,
      pendingMembers: 0,
      newJoins: 0,
      totalBalance: 0.0,
      formattedBalance: '0 đ',
    );
  }
}

class PendingItemModel {
  final int id;
  final String category; // 'finance' or 'event'
  final String type;
  final String title;
  final double amount;
  final String personName;
  final String date;
  final String note;
  final String status;
  final String createdAt;

  PendingItemModel({
    required this.id,
    required this.category,
    required this.type,
    required this.title,
    required this.amount,
    required this.personName,
    required this.date,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  factory PendingItemModel.fromJson(Map<String, dynamic> json) {
    return PendingItemModel(
      id: json['id'] ?? 0,
      category: json['category'] ?? 'finance',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      personName: json['person_name'] ?? '',
      date: json['date'] ?? '',
      note: json['note'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class AdminApiService {
  static String get _baseUrl {
    // Strip known API path suffixes and trailing slash to get raw origin
    var host = ApiConfig.baseUrl
        .replaceAll('/api/flutter/members/', '')
        .replaceAll('/api/flutter/members', '')
        .replaceAll('/api/members/', '')
        .replaceAll('/api/members', '');
    // Remove trailing slash
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }    return '$host/api/flutter/admin';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Lấy thống kê cho Dashboard Quản trị
  static Future<AdminDashboardStats> getDashboardStats(int familyId) async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl/dashboard-stats?family_id=$familyId';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return AdminDashboardStats.fromJson(data);
      }
    } catch (e) {
      debugPrint('[!] AdminApiService.getDashboardStats error: $e');
    }
    return AdminDashboardStats.empty();
  }

  /// Lấy danh sách các yêu cầu đang chờ phê duyệt
  static Future<List<PendingItemModel>> getPendingItems(int familyId) async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl/pending-items?family_id=$familyId';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((i) => PendingItemModel.fromJson(i)).toList();
      }
    } catch (e) {
      debugPrint('[!] AdminApiService.getPendingItems error: $e');
    }
    return [];
  }

  /// Phân quyền thành viên
  static Future<bool> changeMemberRole({
    required int userId,
    required int familyId,
    required String newRole,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl/change-role';
      final body = jsonEncode({
        'user_id': userId,
        'family_id': familyId,
        'new_role': newRole,
      });

      final response = await http.post(Uri.parse(url), headers: headers, body: body);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[!] AdminApiService.changeMemberRole error: $e');
      return false;
    }
  }

  /// Import gia phả bằng tệp Excel (.xlsx / .xls)
  static Future<Map<String, dynamic>> importGenealogyExcel({
    required int familyId,
    required File file,
  }) async {
    try {
      final token = await AuthService.getToken();
      final url = Uri.parse('$_baseUrl/import-excel?family_id=$familyId');
      final request = http.MultipartRequest('POST', url);

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final fileName = file.path.split(Platform.pathSeparator).last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
          contentType: MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'total': data['total_imported'] ?? 0,
          'message': data['message'] ?? 'Import thành công!',
        };
      } else {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': data['detail'] ?? 'Không thể import file Excel',
        };
      }
    } catch (e) {
      debugPrint('[!] AdminApiService.importGenealogyExcel error: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối khi tải file: $e',
      };
    }
  }

  // ==========================================
  // DUYỆT SỰ KIỆN (Events Approval)
  // ==========================================
  static Future<List<AdminEventApprovalModel>> getEventsByStatus({
    required int familyId,
    required String status, // 'pending' or 'approved'
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/events?family_id=$familyId&status=$status');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final list = data['events'] as List? ?? [];
        return list.map((item) => AdminEventApprovalModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[!] AdminApiService.getEventsByStatus error: $e');
      return [];
    }
  }

  static Future<bool> approveEvent(int eventId) async {
    try {
      final headers = await _getHeaders();
      final origin = Uri.parse(_baseUrl).origin;
      final url = Uri.parse('$origin/api/flutter/events/$eventId/approve');
      final response = await http.patch(url, headers: headers).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[!] AdminApiService.approveEvent error: $e');
      return false;
    }
  }

  static Future<bool> rejectEvent(int eventId) async {
    try {
      final headers = await _getHeaders();
      final origin = Uri.parse(_baseUrl).origin;
      final url = Uri.parse('$origin/api/flutter/events/$eventId/reject');
      final response = await http.patch(url, headers: headers).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[!] AdminApiService.rejectEvent error: $e');
      return false;
    }
  }

  // ==========================================
  // DUYỆT THÀNH VIÊN (Members Approval)
  // ==========================================
  static Future<List<AdminMemberApprovalModel>> getMembersByStatus({
    required int familyId,
    required String status, // 'pending' or 'approved'
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/members?family_id=$familyId&status=$status');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final list = data['members'] as List? ?? [];
        return list.map((item) => AdminMemberApprovalModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[!] AdminApiService.getMembersByStatus error: $e');
      return [];
    }
  }

  static Future<bool> approveMember(int memberId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/members/$memberId/approve');
      final response = await http.patch(url, headers: headers).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[!] AdminApiService.approveMember error: $e');
      return false;
    }
  }

  static Future<bool> rejectMember(int memberId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/members/$memberId/reject');
      final response = await http.patch(url, headers: headers).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[!] AdminApiService.rejectMember error: $e');
      return false;
    }
  }

  // ==========================================
  // QUẢN LÝ USER & PHÂN QUYỀN (Users Management)
  // ==========================================
  static Future<List<AdminUserModel>> getFamilyUsers(int familyId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$_baseUrl/users?family_id=$familyId');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final list = data['users'] as List? ?? [];
        return list.map((item) => AdminUserModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[!] AdminApiService.getFamilyUsers error: $e');
      return [];
    }
  }
}

class AdminEventApprovalModel {
  final int id;
  final String title;
  final String creatorName;
  final String date;
  final String location;
  final String note;
  final String eventType;
  final String status;

  AdminEventApprovalModel({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.date,
    required this.location,
    required this.note,
    required this.eventType,
    required this.status,
  });

  factory AdminEventApprovalModel.fromJson(Map<String, dynamic> json) {
    return AdminEventApprovalModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      creatorName: json['creator_name'] ?? 'Thành viên gia đình',
      date: json['date'] ?? '',
      location: json['location'] ?? 'Nhà thờ họ',
      note: json['note'] ?? '',
      eventType: json['event_type'] ?? 'custom',
      status: json['status'] ?? 'pending',
    );
  }
}

class AdminMemberApprovalModel {
  final int id;
  final String fullName;
  final String gender;
  final String birthDate;
  final String address;
  final String fatherName;
  final String motherName;
  final String? avatarUrl;
  final int generation;
  final String phoneNumber;
  final String status;

  AdminMemberApprovalModel({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.birthDate,
    required this.address,
    required this.fatherName,
    required this.motherName,
    this.avatarUrl,
    required this.generation,
    required this.phoneNumber,
    required this.status,
  });

  factory AdminMemberApprovalModel.fromJson(Map<String, dynamic> json) {
    return AdminMemberApprovalModel(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? '',
      gender: json['gender'] ?? 'Nam',
      birthDate: json['birth_date'] ?? '',
      address: json['address'] ?? 'Hà Nội',
      fatherName: json['father_name'] ?? '',
      motherName: json['mother_name'] ?? '',
      avatarUrl: json['avatar_url'],
      generation: json['generation'] ?? 1,
      phoneNumber: json['phone_number'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}

class AdminUserModel {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final String role; // 'admin', 'editor', 'member', 'owner'
  final String gender;
  final String? avatarUrl;
  final String generationInfo;
  final bool isOwner;

  AdminUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.gender,
    this.avatarUrl,
    required this.generationInfo,
    required this.isOwner,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'member',
      gender: json['gender'] ?? 'Nam',
      avatarUrl: json['avatar_url'],
      generationInfo: json['generation_info'] ?? '',
      isOwner: json['is_owner'] ?? false,
    );
  }

  String get roleDisplay {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Quản trị viên';
      case 'owner':
        return 'Chủ gia phả';
      case 'editor':
        return 'Biên tập viên';
      default:
        return 'Thành viên';
    }
  }
}
