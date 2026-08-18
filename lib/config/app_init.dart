import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_config.dart';

/// Hàm khởi tạo ứng dụng: nạp .env và khởi tạo `ApiConfig`.
Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env not found or failed to load: $e');
  }

  // Initialize ApiConfig (reads SharedPreferences override or .env)
  await ApiConfig.init();
  debugPrint('ApiConfig.baseUrl=${ApiConfig.baseUrl}');
}
