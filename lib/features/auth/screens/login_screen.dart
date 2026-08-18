import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../../family/screens/home_screen.dart';
import '../../family/screens/no_family_welcome_screen.dart';
import '../../family/services/family_api_service.dart';
import '../models/auth_request_model.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

/// Màn hình Đăng Nhập phong cách truyền thống cổ kính
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  bool _hasUsernameText = false;

  // Bảng màu thiết kế chuẩn theo mẫu giao diện
  static const Color primaryBrown = Color(0xFF5D2E16);
  static const Color scaffoldBg = Color(0xFFFBF8F2);
  static const Color cardBg = Colors.white;
  static const Color inputBg = Color(0xFFFDFBF7);
  static const Color borderColor = Color(0xFFEADFD2);
  static const Color iconBoxBg = Color(0xFFF5ECE0);
  static const Color textColor = Color(0xFF3E2210);
  static const Color subTextColor = Color(0xFF6E5647);
  static const Color hintColor = Color(0xFFA8988B);
  static const Color bottomCardBg = Color(0xFFF6EFE5);

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      final hasText = _usernameController.text.isNotEmpty;
      if (hasText != _hasUsernameText) {
        setState(() {
          _hasUsernameText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final request = LoginRequestModel(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final result = await AuthService.login(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(result.message ?? 'Đăng nhập thành công!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      final myFamilies = await FamilyApiService.getMyFamilies();

      if (!mounted) return;

      if (myFamilies.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NoFamilyWelcomeScreen(user: result.user),
          ),
        );
      } else {
        await FamilyApiService.saveCurrentFamily(myFamilies.first);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(e.toString().replaceAll('Exception: ', ''))),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // 1. Hình ảnh nền phong cảnh cổ kính ở phần trên
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_header_bg.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF2E9DE),
                    ),
                  ),
                ),
                // Gradient mờ dần từ trên xuống để hòa vào màu nền
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 0.85, 1.0],
                        colors: [
                          scaffoldBg.withValues(alpha: 0.15),
                          scaffoldBg.withValues(alpha: 0.35),
                          scaffoldBg.withValues(alpha: 0.88),
                          scaffoldBg,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Nội dung cuộn
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: bottomInset > 0 ? bottomInset + 20 : 28,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nút Back trên góc trái
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: textColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Logo Cây Gia Phả màu vàng kim
                    Center(child: _buildTreeLogo()),

                    const SizedBox(height: 14),

                    // Tiêu đề "Đăng nhập" với họa tiết mây 2 bên
                    _buildHeaderTitle(),

                    const SizedBox(height: 6),

                    // Slogan "Giữ gìn truyền thống – Kết nối tương lai"
                    const Center(
                      child: Text(
                        'Giữ gìn truyền thống – Kết nối tương lai',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Họa tiết hoa sen & đường chỉ vàng
                    _buildLotusOrnament(),

                    const SizedBox(height: 22),

                    // Khung Card Trắng chứa Form Đăng nhập
                    _buildLoginCard(),

                    const SizedBox(height: 20),

                    // Banner Bảo mật & An toàn ở chân trang
                    _buildSecurityBanner(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Logo Cây Gia Phả hình tròn viền vàng
  Widget _buildTreeLogo() {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC89B3C).withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE5C07B),
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/golden_tree_logo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFE5C17B), Color(0xFF8C5D20)],
              ),
            ),
            child: const Icon(
              Icons.account_tree_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }

  /// Tiêu đề "Đăng nhập" kèm họa tiết mây hoàng gia 2 bên
  Widget _buildHeaderTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Họa tiết mây bên trái
        CustomPaint(
          size: const Size(28, 16),
          painter: _TraditionalCloudPainter(isLeft: true),
        ),
        const SizedBox(width: 10),
        const Text(
          'Đăng nhập',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        // Họa tiết mây bên phải
        CustomPaint(
          size: const Size(28, 16),
          painter: _TraditionalCloudPainter(isLeft: false),
        ),
      ],
    );
  }

  /// Họa tiết hoa sen & đường chỉ vàng bên dưới slogan
  Widget _buildLotusOrnament() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFCDB79E).withValues(alpha: 0.0),
                const Color(0xFFC5A376),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.spa_rounded,
          size: 16,
          color: Color(0xFFC5A376),
        ),
        const SizedBox(width: 8),
        Container(
          width: 46,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFC5A376),
                const Color(0xFFCDB79E).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Card trắng chứa các ô nhập liệu & các nút bấm
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Trường Tên đăng nhập
          _buildInputField(
            title: 'Tên đăng nhập',
            hintText: 'Nhập tên đăng nhập',
            icon: Icons.person_outline_rounded,
            controller: _usernameController,
            suffixIcon: _hasUsernameText
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFFA3968C),
                      size: 20,
                    ),
                    onPressed: () => _usernameController.clear(),
                  )
                : null,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập tên đăng nhập';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // 2. Trường Mật khẩu
          _buildInputField(
            title: 'Mật khẩu',
            hintText: 'Nhập mật khẩu',
            icon: Icons.lock_outline_rounded,
            controller: _passwordController,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: textColor,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // 3. Hàng Ghi nhớ đăng nhập & Quên mật khẩu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Checkbox Ghi nhớ đăng nhập
              GestureDetector(
                onTap: () {
                  setState(() {
                    _rememberMe = !_rememberMe;
                  });
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                        activeColor: primaryBrown,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(
                          color: primaryBrown,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ghi nhớ đăng nhập',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Nút Quên mật khẩu?
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Vui lòng liên hệ quản trị viên dòng họ để cấp lại mật khẩu.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Nút Đăng nhập chính (Nâu đậm)
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                foregroundColor: Colors.white,
                elevation: 1,
                shadowColor: primaryBrown.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.login_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // 5. Đường phân cách "Hoặc đăng ký tài khoản mới"
          _buildDividerWithText('Hoặc đăng ký tài khoản mới'),

          const SizedBox(height: 20),

          // 6. Nút Đăng ký (Viền nâu, nền trắng)
          _buildRegisterOutlineButton(),
        ],
      ),
    );
  }

  /// Ô nhập liệu có icon box bo tròn bên trái
  Widget _buildInputField({
    required String title,
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Box Icon màu nâu kem
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBoxBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: primaryBrown,
            ),
          ),

          const SizedBox(width: 12),

          // Tiêu đề trường & Input
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 1),
                TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  validator: validator,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontSize: 13.5,
                      color: hintColor,
                      fontWeight: FontWeight.normal,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 3),
                    border: InputBorder.none,
                    errorStyle: const TextStyle(fontSize: 11, height: 1),
                  ),
                ),
              ],
            ),
          ),

          // Suffix Icon (nút xóa text / nút xem mật khẩu)
          ?suffixIcon,
        ],
      ),
    );
  }

  /// Đường kẻ phân cách
  Widget _buildDividerWithText(String text) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Color(0xFFDDD0C2),
            thickness: 1,
            endIndent: 12,
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: subTextColor,
          ),
        ),
        const Expanded(
          child: Divider(
            color: Color(0xFFDDD0C2),
            thickness: 1,
            indent: 12,
          ),
        ),
      ],
    );
  }

  /// Nút Đăng ký viền nâu
  Widget _buildRegisterOutlineButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: primaryBrown, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_alt_1_rounded,
              size: 20,
              color: primaryBrown,
            ),
            SizedBox(width: 8),
            Text(
              'Đăng ký',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner Bảo mật & An toàn dưới cùng
  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bottomCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEADBCE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 22,
              color: primaryBrown,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bảo mật & An toàn',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Chúng tôi cam kết bảo vệ thông tin của bạn và gia đình một cách an toàn nhất.',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter vẽ họa tiết mây truyền thống bên cạnh tiêu đề
class _TraditionalCloudPainter extends CustomPainter {
  final bool isLeft;

  _TraditionalCloudPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC5A376)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    if (isLeft) {
      path.moveTo(0, h * 0.7);
      path.quadraticBezierTo(w * 0.3, h * 0.8, w * 0.5, h * 0.6);
      path.quadraticBezierTo(w * 0.8, h * 0.1, w * 0.95, h * 0.5);
      path.quadraticBezierTo(w * 0.7, h * 0.9, w * 0.4, h * 0.6);
    } else {
      path.moveTo(w, h * 0.7);
      path.quadraticBezierTo(w * 0.7, h * 0.8, w * 0.5, h * 0.6);
      path.quadraticBezierTo(w * 0.2, h * 0.1, w * 0.05, h * 0.5);
      path.quadraticBezierTo(w * 0.3, h * 0.9, w * 0.6, h * 0.6);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
