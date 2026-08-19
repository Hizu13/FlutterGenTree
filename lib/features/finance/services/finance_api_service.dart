import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/api_config.dart';
import '../../auth/services/auth_service.dart';
import '../models/transaction_model.dart';

/// Service kết nối REST API Quản lý Thu chi & Quỹ gia tộc (/api/flutter/finance)
class FinanceApiService {
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

  /// Lấy danh sách giao dịch thu chi từ database
  static Future<List<TransactionModel>> getTransactions({
    int? familyId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    String? status,
  }) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final queryParams = <String, String>{};
      if (familyId != null) queryParams['family_id'] = familyId.toString();
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams['type'] = type;
      }
      if (startDate != null) {
        queryParams['start_date'] =
            '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      }
      if (endDate != null) {
        queryParams['end_date'] =
            '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$origin/api/flutter/finance/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data
            .map((json) => TransactionModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('[FinanceApiService] getTransactions failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[FinanceApiService] getTransactions error: $e');
      return [];
    }
  }

  /// Lấy tổng kết Quỹ gia tộc (Số dư, Thu, Chi, Công đức)
  static Future<FinanceSummaryModel> getFinanceSummary(int familyId) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/finance/summary').replace(
        queryParameters: {'family_id': familyId.toString()},
      );

      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return FinanceSummaryModel.fromJson(data as Map<String, dynamic>);
      } else {
        debugPrint('[FinanceApiService] getFinanceSummary failed: ${response.statusCode}');
        return FinanceSummaryModel.empty();
      }
    } catch (e) {
      debugPrint('[FinanceApiService] getFinanceSummary error: $e');
      return FinanceSummaryModel.empty();
    }
  }

  /// Thêm mới một khoản thu / chi / công đức
  static Future<TransactionModel?> createTransaction(TransactionModel tx) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/finance/');
      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(tx.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return TransactionModel.fromJson(data as Map<String, dynamic>);
      } else {
        debugPrint('[FinanceApiService] createTransaction failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[FinanceApiService] createTransaction error: $e');
      return null;
    }
  }

  /// Phê duyệt giao dịch (Admin / Editor)
  static Future<bool> approveTransaction(String id) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/finance/$id/approve');
      final headers = await _getHeaders();

      final response = await http.patch(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[FinanceApiService] approveTransaction error: $e');
      return false;
    }
  }

  /// Từ chối giao dịch (Admin / Editor)
  static Future<bool> rejectTransaction(String id) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/finance/$id/reject');
      final headers = await _getHeaders();

      final response = await http.patch(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[FinanceApiService] rejectTransaction error: $e');
      return false;
    }
  }

  /// Xóa giao dịch (Admin / Editor)
  static Future<bool> deleteTransaction(String id) async {
    try {
      final origin = Uri.parse(baseUrl).origin;
      final uri = Uri.parse('$origin/api/flutter/finance/$id');
      final headers = await _getHeaders();

      final response = await http.delete(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[FinanceApiService] deleteTransaction error: $e');
      return false;
    }
  }
}
