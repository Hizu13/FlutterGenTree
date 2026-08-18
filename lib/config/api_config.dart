import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide API configuration. Call `ApiConfig.init()` before `runApp()`.
class ApiConfig {
  static late String baseUrl;

  /// Initialize baseUrl from (1) SharedPreferences override, (2) .env, (3) sensible fallback.
  static Future<void> init() async {
    String? fromPrefs;
    try {
      final sp = await SharedPreferences.getInstance();
      fromPrefs = sp.getString('API_BASE_URL');
    } catch (_) {
      fromPrefs = null;
    }
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      baseUrl = _normalizeUrl(fromPrefs);
      return;
    }

    try {
      final fromEnv = dotenv.env['API_BASE_URL'];
      if (fromEnv != null && fromEnv.isNotEmpty) {
        baseUrl = _normalizeUrl(fromEnv);
        return;
      }
    } catch (_) {}

    if (kIsWeb) {
      baseUrl = _normalizeUrl('http://localhost:8000/api/flutter/members');
      return;
    }

    baseUrl = _normalizeUrl('http://10.0.2.2:8000/api/flutter/members');
  }

  static Future<void> setRuntimeBaseUrl(String url) async {
    baseUrl = _normalizeUrl(url);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('API_BASE_URL', baseUrl);
  }

  static String _normalizeUrl(String url) {
    var u = url.trim();
    if (!u.endsWith('/')) {
      u = '$u/';
    }
    return u;
  }
}
