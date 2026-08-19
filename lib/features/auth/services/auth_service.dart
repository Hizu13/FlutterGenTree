import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/api_config.dart';
import '../models/auth_request_model.dart';

/// Dịch vụ xử lý Xác thực (Authentication) - Đăng nhập, Đăng ký, Lưu phiên
class AuthService {
  static const String _tokenKey = 'auth_access_token';
  static const String _userKey = 'auth_user_data';

  static String get baseUrl => ApiConfig.baseUrl;

  /// Đăng nhập
  static Future<AuthResponseModel> login(LoginRequestModel request) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final url = Uri.parse('$origin/api/auth/login');

      if (kDebugMode) {
        print('AuthService.login -> POST $url with username: ${request.username}');
      }

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final authResponse = AuthResponseModel.fromJson(data);
        if (authResponse.accessToken != null) {
          await _saveSession(authResponse.accessToken!, authResponse.user);
        }
        return authResponse;
      } else {
        String msg = 'Đăng nhập thất bại (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map) {
            msg = errorData['detail'] ?? errorData['message'] ?? msg;
          }
        } catch (_) {
          final bodyStr = utf8.decode(response.bodyBytes).trim();
          if (bodyStr.isNotEmpty) msg = bodyStr;
        }        throw Exception(msg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthService.login error: $e');
      }
      rethrow;
    }
  }

  /// Đăng ký tài khoản mới
  static Future<AuthResponseModel> register(RegisterRequestModel request) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final url = Uri.parse('$origin/api/auth/register');

      if (kDebugMode) {
        print('AuthService.register -> POST $url with username: ${request.username}');
      }

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: json.encode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final authResponse = AuthResponseModel.fromJson(data);
        if (authResponse.accessToken != null) {
          await _saveSession(authResponse.accessToken!, authResponse.user);
        }
        return authResponse;
      } else {
        String msg = 'Đăng ký thất bại (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map) {
            msg = errorData['detail'] ?? errorData['message'] ?? msg;
          }
        } catch (_) {
          final bodyStr = utf8.decode(response.bodyBytes).trim();
          if (bodyStr.isNotEmpty) msg = bodyStr;
        }        throw Exception(msg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthService.register error: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật thông tin tài khoản
  static Future<UserModel> updateProfile(Map<String, dynamic> updates) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final url = Uri.parse('$origin/api/auth/profile');
      final token = await getToken();
      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(updates),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, json.encode(user.toJson()));
        return user;
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err['detail'] ?? 'Cập nhật thông tin thất bại');
      }
    } catch (e) {
      if (kDebugMode) print('AuthService.updateProfile error: $e');
      rethrow;
    }
  }

  /// Lưu token và thông tin user vào SharedPreferences
  static Future<void> _saveSession(String token, UserModel? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (user != null) {
      await prefs.setString(_userKey, json.encode(user.toJson()));
    }
  }

  /// Lấy token hiện tại
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    // Tự động dọn dẹp nếu phát hiện token giả lập cũ
    if (token != null && token.startsWith('mock_')) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      return null;
    }
    return token;
  }

  /// Lấy thông tin user đã lưu
  static Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userKey);
    if (jsonStr == null) return null;
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Kiểm tra xem người dùng đã đăng nhập trước đó hay chưa
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty && !token.startsWith('mock_');
  }

  /// Đăng xuất
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
