import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/member_model.dart';
import '../../../config/api_config.dart';

/// Service giao tiếp với FastAPI Backend.
/// Tự động chuyển đổi dữ liệu giữa Flutter (camelCase) và Backend.
class MemberApiService {
  // ── Base URL ────────────────────────────────────────────────────────────────
  // Web: dùng localhost trực tiếp (cùng máy).
  // Android Emulator: dùng 10.0.2.2 để truy cập localhost của máy host.
  // iOS Simulator / Desktop: dùng localhost.
  static String get _cleanBaseUrl {
    var u = ApiConfig.baseUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  // ── GET: Lấy toàn bộ danh sách thành viên ─────────────────────────────────
  static Future<List<MemberModel>> fetchAll({int? familyId}) async {
    try {
      String url = _cleanBaseUrl;
      if (familyId != null) {
        url += '?family_id=$familyId';
      }

      // Debug: log requested URL
      try {
        // ignore: avoid_print
        print('MemberApiService.fetchAll -> GET $url');
      } catch (_) {}

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      // Debug: log response status
      try {
        // ignore: avoid_print
        print('MemberApiService.fetchAll -> status ${response.statusCode}');
      } catch (_) {}

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList
            .map((j) => MemberModel.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Debug: log exception
      try {
        // ignore: avoid_print
        print('MemberApiService.fetchAll -> ERROR: $e');
      } catch (_) {}
      throw Exception('Không thể kết nối tới Backend: $e');
    }
  }

  // ── GET: Lấy chi tiết 1 thành viên ────────────────────────────────────────
  static Future<MemberModel> fetchById(String id) async {
    try {
      final url = '$_cleanBaseUrl/$id';
      try {
        // ignore: avoid_print
        print('MemberApiService.fetchById -> GET $url');
      } catch (_) {}
      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return MemberModel.fromJson(jsonData);
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      try {
        // ignore: avoid_print
        print('MemberApiService.fetchById -> ERROR: $e');
      } catch (_) {}
      throw Exception('Không thể lấy thông tin thành viên: $e');
    }
  }

  // ── POST: Tạo thành viên mới ──────────────────────────────────────────────
  static Future<MemberModel> create(MemberModel member) async {
    try {
      final url = '$_cleanBaseUrl/';
      try {
        // ignore: avoid_print
        print(
          'MemberApiService.create -> POST $url body=${member.toJson()}',
        );
      } catch (_) {}
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(member.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return MemberModel.fromJson(jsonData);
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      try {
        // ignore: avoid_print
        print('MemberApiService.create -> ERROR: $e');
      } catch (_) {}
      throw Exception('Không thể thêm thành viên: $e');
    }
  }

  // ── POST: Upload image file and return full URL ───────────────────────────
  static Future<String> uploadImage(File file) async {
    try {
      // Build upload URI from baseUrl origin to avoid path replacement issues
      final origin = Uri.parse(_cleanBaseUrl).origin; // e.g. http://10.0.2.2:8000
      final uri = Uri.parse('$origin/upload/image');
      // Debug
      try {
        // ignore: avoid_print
        print('MemberApiService.uploadImage -> POST $uri');
      } catch (_) {}

      final request = http.MultipartRequest('POST', uri);
      final fileName = file.path.split(Platform.pathSeparator).last;
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final parts = mimeType.split('/');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
          contentType: MediaType(parts[0], parts[1]),
        ),
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body) as Map<String, dynamic>;
        final rel = jsonData['url'] as String? ?? '';
        // Keep backend URL portable: store relative path in DB and resolve it
        // on the client using the runtime API base URL.
        if (rel.isNotEmpty) return rel;
        throw Exception('Upload response missing URL');
      } else {
        throw Exception('Upload failed ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      try {
        // ignore: avoid_print
        print('MemberApiService.uploadImage -> ERROR: $e');
      } catch (_) {}
      rethrow;
    }
  }

  // ── PUT: Cập nhật thành viên ───────────────────────────────────────────────
  static Future<MemberModel> update(String id, MemberModel member) async {
    try {
      final url = '$_cleanBaseUrl/$id';
      try {
        // ignore: avoid_print
        print('MemberApiService.update -> PUT $url body=${member.toJson()}');
      } catch (_) {}
      final response = await http
          .put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(member.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return MemberModel.fromJson(jsonData);
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      try {
        // ignore: avoid_print
        print('MemberApiService.update -> ERROR: $e');
      } catch (_) {}
      throw Exception('Không thể cập nhật thành viên: $e');
    }
  }

  // ── PUT: Cập nhật vai trò thành viên (Phân quyền editor/member) ───────────
  static Future<void> updateRole(String id, String role) async {
    try {
      final url = '$_cleanBaseUrl/$id/role';
      try {
        // ignore: avoid_print
        print('MemberApiService.updateRole -> PUT $url body: role=$role');
      } catch (_) {}
      final response = await http
          .put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'role': role}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      try {
        // ignore: avoid_print
        print('MemberApiService.updateRole -> ERROR: $e');
      } catch (_) {}
      throw Exception('Không thể cập nhật vai trò: $e');
    }
  }

  // ── DELETE: Xóa thành viên ─────────────────────────────────────────────────
  static Future<void> delete(String id) async {
    try {
      final url = '$_cleanBaseUrl/$id';
      try {
        // ignore: avoid_print
        print('MemberApiService.delete -> DELETE $url');
      } catch (_) {}
      final response = await http
          .delete(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        String errorMsg = 'Lỗi ${response.statusCode}: ${response.body}';
        try {
          final bodyJson = jsonDecode(utf8.decode(response.bodyBytes));
          if (bodyJson is Map && bodyJson.containsKey('detail')) {
            errorMsg = bodyJson['detail'].toString();
          }
        } catch (_) {}
        throw Exception(errorMsg);      }
    } catch (e) {
      try {
        // ignore: avoid_print
        print('MemberApiService.delete -> ERROR: $e');
      } catch (_) {}
      final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Exception: ', '');
      throw Exception(msg);    }
  }

  // ── GET/POST: Tìm kiếm mối quan hệ huyết thống giữa 2 thành viên ─────────
  static Future<Map<String, dynamic>?> findRelationshipPath(int fromId, int toId) async {
    try {
      final url = '$_cleanBaseUrl/path?from_id=$fromId&to_id=$toId';
      try {
        // ignore: avoid_print
        print('MemberApiService.findRelationshipPath -> GET $url');
      } catch (_) {}

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return decoded;
      } else {
        try {
          // ignore: avoid_print
          print('MemberApiService.findRelationshipPath -> Error ${response.statusCode}: ${response.body}');
        } catch (_) {}
        return null;
      }
    } catch (e) {
      try {
        // ignore: avoid_print
        print('MemberApiService.findRelationshipPath -> Exception: $e');
      } catch (_) {}
      return null;
    }
  }
}
