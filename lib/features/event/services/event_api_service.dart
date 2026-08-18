import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/api_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/event_model.dart';

/// Service kết nối REST API sự kiện (/api/flutter/events)
class EventApiService {
  static String get baseUrl => ApiConfig.baseUrl;

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

  /// Lấy danh sách toàn bộ sự kiện của gia phả (Tự động đồng bộ sinh nhật & ngày giỗ)
  static Future<List<EventModel>> getEvents({
    int? familyId,
    int? year,
    int? month,
    bool autoSync = true,
  }) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final queryParams = <String, String>{};
      if (familyId != null) queryParams['family_id'] = familyId.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      queryParams['auto_sync'] = autoSync.toString();

      final uri = Uri.parse('$origin/api/flutter/events/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => EventModel.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        debugPrint('[EventApiService] getEvents failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[EventApiService] getEvents error: $e');
      return [];
    }
  }

  /// Lấy danh sách sự kiện sắp tới trong X ngày
  static Future<List<EventModel>> getUpcomingEvents({
    int? familyId,
    int days = 30,
  }) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final queryParams = <String, String>{
        'days': days.toString(),
      };
      if (familyId != null) queryParams['family_id'] = familyId.toString();

      final uri = Uri.parse('$origin/api/flutter/events/upcoming/all').replace(
        queryParameters: queryParams,
      );

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => EventModel.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('[EventApiService] getUpcomingEvents error: $e');
      return [];
    }
  }

  /// Thêm sự kiện mới
  static Future<EventModel?> createEvent(EventModel event) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/events/');
      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(event.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return EventModel.fromJson(data as Map<String, dynamic>);
      } else {
        debugPrint('[EventApiService] createEvent failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[EventApiService] createEvent error: $e');
      return null;
    }
  }

  /// Cập nhật thông tin sự kiện
  static Future<EventModel?> updateEvent(EventModel event) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/events/${event.id}');
      final headers = await _getHeaders();

      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(event.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return EventModel.fromJson(data as Map<String, dynamic>);
      } else {
        debugPrint('[EventApiService] updateEvent failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[EventApiService] updateEvent error: $e');
      return null;
    }
  }

  /// Xóa sự kiện theo ID
  static Future<bool> deleteEvent(String eventId) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/events/$eventId');
      final headers = await _getHeaders();

      final response = await http.delete(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EventApiService] deleteEvent error: $e');
      return false;
    }
  }

  /// Kích hoạt đồng bộ sự kiện sinh nhật & ngày giỗ thủ công
  static Future<bool> syncEvents(int familyId) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/events/sync/$familyId');
      final headers = await _getHeaders();

      final response = await http.post(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EventApiService] syncEvents error: $e');
      return false;
    }
  }
}
