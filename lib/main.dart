import 'package:flutter/material.dart';
import 'config/app_color.dart';
import 'config/app_init.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/family/screens/home_screen.dart';
import 'features/family/screens/no_family_welcome_screen.dart';
import 'features/family/services/family_api_service.dart';

Future<void> main() async {
  await initializeApp();

  final bool loggedIn = await AuthService.isLoggedIn();
  Widget initialScreen;
  if (loggedIn) {
    // Nếu đã đăng nhập, kiểm tra thông tin gia phả
    final cachedFamily = await FamilyApiService.getCurrentFamily();
    if (cachedFamily != null) {
      initialScreen = const HomeScreen();
    } else {
      try {
        final myFamilies = await FamilyApiService.getMyFamilies();
        if (myFamilies.isEmpty) {
          final user = await AuthService.getSavedUser();
          initialScreen = NoFamilyWelcomeScreen(user: user);
        } else {
          await FamilyApiService.saveCurrentFamily(myFamilies.first);
          initialScreen = const HomeScreen();
        }
      } catch (_) {
        initialScreen = const HomeScreen();
      }
    }
  } else {
    // Lần đầu vào app hoặc chưa đăng nhập -> vào màn hình Đăng nhập
    initialScreen = const LoginScreen();
  }
  runApp(MyApp(initialScreen: initialScreen));}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, this.initialScreen = const HomeScreen()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryGold,
          surface: AppColors.white,
        ),
      ),
      home: initialScreen,
    );
  }
}