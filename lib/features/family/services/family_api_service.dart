import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/api_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/family_model.dart';

/// Dịch vụ API xử lý Gia Phả (Family)
/// Tương tác trực tiếp với Backend FastAPI (/api/families)
class FamilyApiService {
  static const String _currentFamilyKey = 'current_active_family';

  static String get baseUrl => ApiConfig.baseUrl;

  /// Helper lấy Headers kèm Authorization Token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Lấy danh sách gia phả của người dùng hiện tại
  static Future<List<FamilyModel>> getMyFamilies() async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final url = Uri.parse('$origin/api/families/my');
      final headers = await _getHeaders();

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final listJson = data['data'] as List<dynamic>? ?? [];
        return listJson.map((e) => FamilyModel.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        if (kDebugMode) {
          print('FamilyApiService.getMyFamilies -> status ${response.statusCode}: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('FamilyApiService.getMyFamilies error: $e');
      }
      return [];
    }
  }

  /// Tạo gia phả mới
  static Future<FamilyModel> createFamily({
    required String name,
    String? description,
    String? originLocation,
    String? joinCode,
  }) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final url = Uri.parse('$origin/api/families');
      final headers = await _getHeaders();

      final body = {
        'name': name.trim(),
        if (description != null && description.isNotEmpty) 'description': description.trim(),
        if (originLocation != null && originLocation.isNotEmpty) 'origin_location': originLocation.trim(),
        if (joinCode != null && joinCode.isNotEmpty) 'join_code': joinCode.trim().toUpperCase(),
      };

      if (kDebugMode) {
        print('FamilyApiService.createFamily -> POST $url body: $body');
      }

      final response = await http
          .post(
            url,
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final familyJson = data['data'] as Map<String, dynamic>;
        final createdFamily = FamilyModel.fromJson(familyJson);
        await saveCurrentFamily(createdFamily);
        return createdFamily;
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        final msg = errorData['detail'] ?? errorData['message'] ?? 'Tạo gia phả thất bại (${response.statusCode})';
        throw Exception(msg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FamilyApiService.createFamily error: $e. Checking if family was created in background...');
      }
      // Kiểm tra dự phòng: nếu server đã tạo thành công trong DB
      try {
        final myFamilies = await getMyFamilies();
        final matched = myFamilies.where((f) => f.name.trim() == name.trim()).toList();
        if (matched.isNotEmpty) {
          final createdFamily = matched.last;
          await saveCurrentFamily(createdFamily);
          return createdFamily;
        }
      } catch (_) {}

      rethrow;
    }
  }

  /// Tham gia gia phả bằng mã join_code
  static Future<FamilyJoinResult> joinFamily({
    required String joinCode,
    String branchType = 'Họ nội',
  }) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final url = Uri.parse('$origin/api/families/join');
      final headers = await _getHeaders();

      final body = {
        'join_code': joinCode.trim().toUpperCase(),
        'branch_type': branchType,
      };

      final response = await http
          .post(
            url,
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
                final bool requiresApproval = data['requires_approval'] == true || data['data'] == null;

        if (requiresApproval) {
          final msg = data['message'] ?? 'Yêu cầu tham gia gia phả đã được gửi, vui lòng chờ quản trị viên phê duyệt!';
          return FamilyJoinResult(
            success: true,
            requiresApproval: true,
            message: msg,
            family: null,
          );
        }

        final familyJson = data['data'] as Map<String, dynamic>;
        final joinedFamily = FamilyModel.fromJson(familyJson);
        await saveCurrentFamily(joinedFamily);
        return FamilyJoinResult(
          success: true,
          requiresApproval: false,
          message: data['message'] ?? 'Tham gia gia phả thành công!',
          family: joinedFamily,
        );      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        final msg = errorData['detail'] ?? errorData['message'] ?? 'Tham gia gia phả thất bại (${response.statusCode})';
        throw Exception(msg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FamilyApiService.joinFamily error: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật thông tin gia phả (Tên, Nguồn gốc / Quê quán, Mô tả)
  static Future<FamilyModel> updateFamily({
    required int familyId,
    required String name,
    String? description,
    String? originLocation,
  }) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final url = Uri.parse('$origin/api/families/$familyId');
      final headers = await _getHeaders();

      final body = {
        'name': name.trim(),
        'description': description?.trim(),
        'origin_location': originLocation?.trim(),
      };

      final response = await http
          .put(
            url,
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final familyJson = data['data'] as Map<String, dynamic>;
        final updatedFamily = FamilyModel.fromJson(familyJson);
        await saveCurrentFamily(updatedFamily);
        return updatedFamily;
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        final msg = errorData['detail'] ?? errorData['message'] ?? 'Cập nhật gia phả thất bại';
        throw Exception(msg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('FamilyApiService.updateFamily error: $e');
      }
      rethrow;
    }
  }

  /// Lưu gia phả đang chọn vào Local Storage
  static Future<void> saveCurrentFamily(FamilyModel family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentFamilyKey, json.encode(family.toJson()));
  }

  /// Lấy gia phả đang chọn từ Local Storage
  static Future<FamilyModel?> getCurrentFamily() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_currentFamilyKey);
    if (jsonStr == null) return null;
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return FamilyModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Xóa gia phả hiện tại (khi đăng xuất)
  static Future<void> clearCurrentFamily() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentFamilyKey);
  }
}

class FamilyJoinResult {
  final bool success;
  final bool requiresApproval;
  final String message;
  final FamilyModel? family;

  FamilyJoinResult({
    required this.success,
    required this.requiresApproval,
    required this.message,
    this.family,
  });
}
