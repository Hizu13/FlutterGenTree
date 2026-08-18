import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/auth_request_model.dart';
import '../services/auth_service.dart';
import '../widgets/traditional_footer_painter.dart';
import 'login_screen.dart';

/// Màn hình Đăng Ký Tài Khoản
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  final _emailController = TextEditingController();
  final _cccdController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Bảng màu thiết kế chuẩn
  static const Color primaryBrown = Color(0xFF6B3E1E);
  static const Color scaffoldBg = Color(0xFFFAF6F0);
  static const Color cardBg = Colors.white;
  static const Color inputBg = Color(0xFFFAF8F5);
  static const Color borderColor = Color(0xFFE8DFD5);
  static const Color iconBoxBg = Color(0xFFF7EFE4);

  final List<String> _genderOptions = ['Nam', 'Nữ', 'Khác'];

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _placeOfBirthController.dispose();
    _emailController.dispose();
    _cccdController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? dobString;
    if (_selectedDateOfBirth != null) {
      final d = _selectedDateOfBirth!.day.toString().padLeft(2, '0');
      final m = _selectedDateOfBirth!.month.toString().padLeft(2, '0');
      final y = _selectedDateOfBirth!.year.toString();
      dobString = '$d/$m/$y';
    }

    try {
      final request = RegisterRequestModel(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        lastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        gender: _selectedGender,
        dateOfBirth: dobString,
        placeOfBirth: _placeOfBirthController.text.trim().isEmpty ? null : _placeOfBirthController.text.trim(),
        email: _emailController.text.trim(),
        cccd: _cccdController.text.trim().isEmpty ? null : _cccdController.text.trim(),
        role: 'member', // Mặc định luôn là member theo yêu cầu
      );

      final result = await AuthService.register(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(result.message ?? 'Đăng ký tài khoản thành công!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Chuyển hướng sang màn hình đăng nhập hoặc quay lại
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBrown,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2D1C10),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryBrown,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Đăng ký tài khoản',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Phong cảnh cổ kính chân trang
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TraditionalLandscapeFooter(height: 140, opacity: 0.45),
          ),

          // 2. Nội dung Form Đăng ký
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: bottomInset > 0 ? bottomInset + 20 : 30,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Form Đăng ký
                    _buildRegisterCard(),

                    const SizedBox(height: 20),

                    // Nút Đăng ký chính
                    _buildSubmitButton(),

                    const SizedBox(height: 18),

                    // Link chuyển về Đăng nhập
                    _buildLoginLink(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ Card chứa toàn bộ các trường đăng ký
  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Tên đăng nhập *
          _buildFormRow(
            title: 'Tên đăng nhập *',
            hintText: 'Nhập tên đăng nhập',
            icon: Icons.person_rounded,
            controller: _usernameController,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập tên đăng nhập';
              }
              if (val.trim().length < 3) {
                return 'Tên đăng nhập tối thiểu 3 ký tự';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // 2. Mật khẩu *
          _buildFormRow(
            title: 'Mật khẩu *',
            hintText: 'Nhập mật khẩu',
            icon: Icons.lock_rounded,
            controller: _passwordController,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF6B482A),
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              if (val.length < 6) {
                return 'Mật khẩu tối thiểu 6 ký tự';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // 3. Họ *
          _buildFormRow(
            title: 'Họ *',
            hintText: 'Nhập họ',
            icon: Icons.person_outline_rounded,
            controller: _lastNameController,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập họ';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // 4. Tên *
          _buildFormRow(
            title: 'Tên *',
            hintText: 'Nhập tên',
            icon: Icons.badge_outlined,
            controller: _firstNameController,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập tên';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // 5. Giới tính (Dropdown)
          _buildDropdownRow(
            title: 'Giới tính',
            hintText: 'Chọn giới tính',
            icon: Icons.wc_rounded,
            value: _selectedGender,
            items: _genderOptions,
            onChanged: (val) {
              setState(() => _selectedGender = val);
            },
          ),

          const SizedBox(height: 12),

          // 6. Ngày sinh (DatePicker)
          _buildDatePickerRow(
            title: 'Ngày sinh',
            hintText: 'Chọn ngày sinh',
            icon: Icons.calendar_today_outlined,
            selectedDate: _selectedDateOfBirth,
            onTap: _pickDateOfBirth,
          ),

          const SizedBox(height: 12),

          // 7. Quê quán
          _buildFormRow(
            title: 'Quê quán',
            hintText: 'Nhập quê quán',
            icon: Icons.location_on_outlined,
            controller: _placeOfBirthController,
          ),

          const SizedBox(height: 12),

          // 8. Email *
          _buildFormRow(
            title: 'Email *',
            hintText: 'Nhập email',
            icon: Icons.email_outlined,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Vui lòng nhập email';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(val.trim())) {
                return 'Email không hợp lệ';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // 9. Số CCCD (tùy chọn)
          _buildFormRow(
            title: 'Số CCCD / CMND',
            hintText: 'Nhập số CCCD (tùy chọn)',
            icon: Icons.credit_card_outlined,
            controller: _cccdController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  /// Ô nhập liệu chuẩn
  Widget _buildFormRow({
    required String title,
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Box Icon màu nâu kem
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBoxBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 21,
              color: primaryBrown,
            ),
          ),

          const SizedBox(width: 12),

          // Cột Tiêu đề & TextField
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B482A),
                  ),
                ),
                TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  validator: validator,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D1C10),
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    errorStyle: const TextStyle(fontSize: 11, height: 1),
                  ),
                ),
              ],
            ),
          ),

          ?suffixIcon,
        ],
      ),
    );
  }

  /// Ô Dropdown chọn Giới tính
  Widget _buildDropdownRow({
    required String title,
    required String hintText,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBoxBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 21,
              color: primaryBrown,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B482A),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Text(
                      hintText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6B482A),
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D1C10),
                    ),
                    items: items.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ô DatePicker chọn Ngày sinh
  Widget _buildDatePickerRow({
    required String title,
    required String hintText,
    required IconData icon,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    String displayDate = hintText;
    if (selectedDate != null) {
      final d = selectedDate.day.toString().padLeft(2, '0');
      final m = selectedDate.month.toString().padLeft(2, '0');
      final y = selectedDate.year.toString();
      displayDate = '$d/$m/$y';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBoxBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: primaryBrown,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B482A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayDate,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: selectedDate != null
                            ? const Color(0xFF2D1C10)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6B482A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút Đăng ký Submit
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryBrown.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.person_add_alt_1_rounded,
                size: 20,
                color: Colors.white,
              ),
        label: Text(
          _isLoading ? 'Đang xử lý...' : 'Đăng ký',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  /// Hàng text "Đã có tài khoản? Đăng nhập ngay"
  Widget _buildLoginLink() {
    return Center(
      child: InkWell(
        onTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: RichText(
            text: const TextSpan(
              text: 'Đã có tài khoản? ',
              style: TextStyle(
                color: Color(0xFF6B482A),
                fontSize: 14,
              ),
              children: [
                TextSpan(
                  text: 'Đăng nhập ngay',
                  style: TextStyle(
                    color: primaryBrown,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
