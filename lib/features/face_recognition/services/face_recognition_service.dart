import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../../../config/api_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/face_match_model.dart';

class FaceRecognitionApiService {
  static String get _baseUrl {
    var host = ApiConfig.baseUrl
        .replaceAll('/api/flutter/members/', '')
        .replaceAll('/api/flutter/members', '')
        .replaceAll('/api/members/', '')
        .replaceAll('/api/members', '');
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return '$host/api/flutter/face';
  }

  /// Quét khuôn mặt từ file ảnh / camera frame và tìm kiếm trong dòng họ
  static Future<List<FaceSearchResult>> searchFace({
    required int familyId,
    required File imageFile,
    double threshold = 0.93,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/search');
      final request = http.MultipartRequest('POST', uri);

      // Thêm token nếu có
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['family_id'] = familyId.toString();
      request.fields['threshold'] = threshold.toString();

      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final mimeSplits = mimeType.split('/');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType(mimeSplits[0], mimeSplits[1]),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['success'] == true && decoded['results'] != null) {
          final resultsList = decoded['results'] as List<dynamic>;
          return resultsList.map((item) => FaceSearchResult.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[FaceAPI] searchFace error: $e');
      return [];
    }
  }

  /// Quét và cắt các khuôn mặt trong ảnh nhóm để cho người dùng chọn
  static Future<List<FaceCandidate>> detectCandidates(File imageFile) async {
    try {
      final uri = Uri.parse('$_baseUrl/detect-candidates');
      final request = http.MultipartRequest('POST', uri);

      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final mimeSplits = mimeType.split('/');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType(mimeSplits[0], mimeSplits[1]),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['success'] == true && decoded['candidates'] != null) {
          final list = decoded['candidates'] as List<dynamic>;
          return list.map((item) => FaceCandidate.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[FaceAPI] detectCandidates error: $e');
      return [];
    }
  }

  /// Xác nhận lưu khuôn mặt thành viên vào MySQL
  static Future<bool> enrollFace({
    required int familyId,
    required int memberId,
    String? cropImageBase64,
    List<double>? embedding,
    String? faceBox,
    File? imageFile,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/enroll');
      final request = http.MultipartRequest('POST', uri);

      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['family_id'] = familyId.toString();
      request.fields['member_id'] = memberId.toString();
      request.fields['is_primary'] = 'true';

      if (cropImageBase64 != null) {
        request.fields['crop_image_base64'] = cropImageBase64;
      }
      if (embedding != null) {
        request.fields['embedding_json'] = json.encode(embedding);
      }
      if (faceBox != null) {
        request.fields['face_box'] = faceBox;
      }
      if (imageFile != null) {
        final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
        final mimeSplits = mimeType.split('/');
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
            contentType: MediaType(mimeSplits[0], mimeSplits[1]),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[FaceAPI] enrollFace error: $e');
      return false;
    }
  }

  /// Tự động quét toàn bộ Avatar của dòng họ để nạp và lập chỉ mục véc-tơ AI
  static Future<Map<String, dynamic>> reindexFamily(int familyId) async {
    try {
      final uri = Uri.parse('$_baseUrl/reindex-family/$familyId');
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(uri, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': 'Không thể đồng bộ dữ liệu (${response.statusCode})'};
    } catch (e) {
      debugPrint('[FaceAPI] reindexFamily error: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }
}
