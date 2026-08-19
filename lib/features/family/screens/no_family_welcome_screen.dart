import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../../auth/models/auth_request_model.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../models/family_model.dart';
import '../services/family_api_service.dart';
import 'home_screen.dart';

/// Màn hình chào mừng khi người dùng chưa tham gia vào bất kỳ gia phả nào
/// Cung cấp 2 lựa chọn: Tạo gia phả mới hoặc Nhập mã gia phả đã có.
class NoFamilyWelcomeScreen extends StatefulWidget {
  final UserModel? user;

  const NoFamilyWelcomeScreen({super.key, this.user});

  @override
  State<NoFamilyWelcomeScreen> createState() => _NoFamilyWelcomeScreenState();
}

class _NoFamilyWelcomeScreenState extends State<NoFamilyWelcomeScreen> {
  UserModel? _currentUser;
  final TextEditingController _joinCodeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _joinFocusNode = FocusNode();

  String _selectedBranch = 'Họ nội'; // 'Họ nội' hoặc 'Họ ngoại'
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      _loadCurrentUser();
    }
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _scrollController.dispose();
    _joinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getSavedUser();
    if (mounted && user != null) {
      setState(() => _currentUser = user);
    }
  }

  /// Xử lý Đăng xuất
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.badgeRed, size: 24),
            SizedBox(width: 8),
            Text(
              'Đăng xuất',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.badgeRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FamilyApiService.clearCurrentFamily();
      await AuthService.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đăng xuất thành công'),
            backgroundColor: AppColors.primaryDark,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Mở Modal Chỉnh sửa thông tin cá nhân
  void _showEditProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileBottomSheet(
        user: _currentUser,
        onProfileUpdated: (updatedUser) {
          setState(() {
            _currentUser = updatedUser;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Cập nhật thông tin cá nhân thành công!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  /// Xử lý tham gia gia phả bằng mã code
  Future<void> _handleJoinFamily() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Vui lòng nhập mã gia phả'),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _joinFocusNode.requestFocus();
      return;
    }

    setState(() => _isJoining = true);

    try {
      final result = await FamilyApiService.joinFamily(
        joinCode: code,
        branchType: _selectedBranch,
      );

      if (!mounted) return;

      if (result.requiresApproval || result.family == null) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
                      SizedBox(width: 8),
                      Text('Chờ phê duyệt', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: Text(
                    result.message,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              return;
            }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Đã tham gia gia phả "${result.family!.name}"!'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
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
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// Mở BottomSheet Tạo gia phả mới
  void _showCreateFamilyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateFamilyBottomSheet(
        onSuccess: (newFamily) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Tạo gia phả "${newFamily.name}" thành công!'),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        },
      ),
    );
  }

  void _scrollToJoinSection() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    _joinFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final userName = _currentUser?.fullName.isNotEmpty == true
        ? _currentUser!.fullName
        : (_currentUser?.username.isNotEmpty == true ? _currentUser!.username : 'Thành viên');

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Header Bar (Dark Brown) với 3 chấm & Thông báo
            _buildTopHeader(userName),

            // 2. Nội dung chính có cuộn
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Minh họa Cây gia phả & Đại gia đình
                    _buildHeroIllustration(),

                    const SizedBox(height: 18),

                    // Tiêu đề & Lời nhắn
                    const Text(
                      'Bạn chưa tham gia gia phả nào',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDeep,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tham gia gia phả để kết nối với các thành viên\ntrong dòng họ của bạn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Card 1: Tạo gia phả mới
                    _buildActionCard(
                      iconWidget: _buildCardIcon(
                        icon: Icons.park_outlined,
                        badgeIcon: Icons.add,
                        bgColor: AppColors.adminRoleBg,
                        iconColor: AppColors.primary,
                      ),
                      title: 'Tạo gia phả mới',
                      subtitle:
                          'Tạo gia phả riêng cho dòng họ của bạn và mời các thành viên tham gia.',
                      buttonText: 'Tạo ngay',
                      onTapButton: _showCreateFamilyModal,
                    ),

                    const SizedBox(height: 16),

                    // Card 2: Nhập mã gia phả
                    _buildActionCard(
                      iconWidget: _buildCardIcon(
                        icon: Icons.people_alt_outlined,
                        badgeIcon: Icons.search,
                        bgColor: AppColors.adminRoleBg,
                        iconColor: AppColors.primary,
                      ),
                      title: 'Nhập mã gia phả',
                      subtitle:
                          'Nhập mã gia phả để gửi yêu cầu tham gia vào gia phả đã có.',
                      buttonText: 'Nhập mã',
                      onTapButton: _scrollToJoinSection,
                    ),

                    const SizedBox(height: 20),

                    // Card 3: Form nhập mã tham gia
                    _buildJoinFormCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Top Header với Nút Thông báo và Menu 3 Chấm
  Widget _buildTopHeader(String userName) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryExtraDark,
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: _showEditProfileModal,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Tên user
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Xin chào,',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action Pill chứa: Chuông Thông báo & Menu 3 Chấm
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nút Chuông thông báo
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không có thông báo mới'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // Menu 3 Chấm Popup
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  color: Colors.white,
                  elevation: 6,
                  offset: const Offset(0, 42),
                  onSelected: (value) {
                    if (value == 'profile') {
                      _showEditProfileModal();
                    } else if (value == 'logout') {
                      _handleLogout();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'profile',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                          SizedBox(width: 10),
                          Text(
                            'Chỉnh sửa thông tin',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 18, color: AppColors.badgeRed),
                          SizedBox(width: 10),
                          Text(
                            'Đăng xuất',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.badgeRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Hero Graphic Illustration
  Widget _buildHeroIllustration() {
    return SizedBox(
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft tree silhouette
          Opacity(
            opacity: 0.15,
            child: const Icon(
              Icons.park_rounded,
              size: 130,
              color: Color(0xFF8D4B20),
            ),
          ),
          // Group of silhouettes
          Positioned(
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPersonSilhouette(height: 42, color: const Color(0xFFCBB6A4)),
                const SizedBox(width: 4),
                _buildPersonSilhouette(height: 52, color: const Color(0xFFB59A84)),
                const SizedBox(width: 6),
                _buildPersonSilhouette(height: 60, color: const Color(0xFF9E7E66)),
                const SizedBox(width: 6),
                _buildPersonSilhouette(height: 54, color: const Color(0xFFB59A84)),
                const SizedBox(width: 4),
                _buildPersonSilhouette(height: 44, color: const Color(0xFFCBB6A4)),
              ],
            ),
          ),
          // Subtle warm decorative clouds
          Positioned(
            left: 24,
            top: 40,
            child: Icon(
              Icons.cloud_queue_rounded,
              size: 26,
              color: const Color(0xFFE2D4C7).withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            right: 24,
            top: 48,
            child: Icon(
              Icons.cloud_queue_rounded,
              size: 22,
              color: const Color(0xFFE2D4C7).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonSilhouette({required double height, required Color color}) {
    final headSize = height * 0.32;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: headSize,
          height: headSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: headSize * 1.5,
          height: height - headSize - 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(headSize * 0.7),
              topRight: Radius.circular(headSize * 0.7),
            ),
          ),
        ),
      ],
    );
  }

  /// 3. Icon tròn cho các Card hành động
  Widget _buildCardIcon({
    required IconData icon,
    required IconData badgeIcon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 28, color: iconColor),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor,
              ),
              child: Icon(badgeIcon, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Action Card Component
  Widget _buildActionCard({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTapButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onTapButton,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Form Card: Chọn họ & Nhập mã gia phả
  Widget _buildJoinFormCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Chọn họ tham gia
          const Text(
            '1. Chọn họ tham gia',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDeep,
            ),
          ),
          const SizedBox(height: 12),

          // Hai lựa chọn: Họ nội / Họ ngoại
          Row(
            children: [
              Expanded(
                child: _buildBranchSelectCard(
                  label: 'Họ nội',
                  isSelected: _selectedBranch == 'Họ nội',
                  onTap: () => setState(() => _selectedBranch = 'Họ nội'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBranchSelectCard(
                  label: 'Họ ngoại',
                  isSelected: _selectedBranch == 'Họ ngoại',
                  onTap: () => setState(() => _selectedBranch = 'Họ ngoại'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Nhập mã gia phả
          const Text(
            '2. Nhập mã gia phả',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDeep,
            ),
          ),
          const SizedBox(height: 10),

          // Input Text Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderMuted),
            ),
            child: TextField(
              controller: _joinCodeController,
              focusNode: _joinFocusNode,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Nhập mã gia phả',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  tooltip: 'Quét mã QR',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng quét QR đang được cập nhật'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Gợi ý thông tin
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textBrownMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mã gia phả do quản trị viên cung cấp.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBrownMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Nút "Gửi yêu cầu tham gia"
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isJoining ? null : _handleJoinFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isJoining
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Gửi yêu cầu tham gia',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSelectCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7EE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6B3E1E) : const Color(0xFFE5DCD3),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.park_outlined,
              size: 24,
              color: isSelected ? const Color(0xFF6B3E1E) : const Color(0xFFA3968C),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF3B200E) : const Color(0xFF7D6E65),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF6B3E1E),
              ),
          ],
        ),
      ),
    );
  }
}

/// BottomSheet Chỉnh sửa thông tin cá nhân
class _EditProfileBottomSheet extends StatefulWidget {
  final UserModel? user;
  final Function(UserModel updatedUser) onProfileUpdated;

  const _EditProfileBottomSheet({
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  State<_EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<_EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _cccdController;
  late TextEditingController _placeOfBirthController;
  late TextEditingController _dobController;

  String? _gender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _firstNameController = TextEditingController(text: u?.firstName ?? '');
    _lastNameController = TextEditingController(text: u?.lastName ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _cccdController = TextEditingController(text: u?.cccd ?? '');
    _placeOfBirthController = TextEditingController(text: u?.placeOfBirth ?? '');
    _dobController = TextEditingController(text: u?.dateOfBirth ?? '');
    _gender = u?.gender ?? 'Nam';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _cccdController.dispose();
    _placeOfBirthController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6B3E1E),
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
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        _dobController.text = '$day/$month/$year';
      });
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'gender': _gender,
        'date_of_birth': _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        'place_of_birth': _placeOfBirthController.text.trim().isNotEmpty ? _placeOfBirthController.text.trim() : null,
        'cccd': _cccdController.text.trim().isNotEmpty ? _cccdController.text.trim() : null,
      };

      final updatedUser = await AuthService.updateProfile(updates);
      widget.onProfileUpdated(updatedUser);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDD2C4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Color(0xFF6B3E1E), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Chỉnh sửa thông tin cá nhân',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D1C10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Họ đệm & Tên
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Họ đệm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            hintText: 'Nguyễn',
                            filled: true,
                            fillColor: const Color(0xFFFAF7F2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tên *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            hintText: 'Văn A',
                            filled: true,
                            fillColor: const Color(0xFFFAF7F2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Email
              const Text('Email *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'email@example.com',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập Email' : null,
              ),
              const SizedBox(height: 14),

              // Giới tính
              const Text('Giới tính', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: ['Nam', 'Nữ', 'Khác'].map((g) {
                  final isSel = _gender == g;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: isSel,
                      selectedColor: const Color(0xFF6B3E1E),
                      labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF3B200E)),
                      onSelected: (sel) {
                        if (sel) setState(() => _gender = g);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Ngày sinh
              const Text('Ngày sinh', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: _pickDateOfBirth,
                decoration: InputDecoration(
                  hintText: 'dd/MM/yyyy',
                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // CCCD
              const Text('Số CCCD / CMND', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _cccdController,
                decoration: InputDecoration(
                  hintText: '12 chữ số',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // Nút Lưu
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B3E1E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Lưu thay đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// BottomSheet tạo gia phả mới
class _CreateFamilyBottomSheet extends StatefulWidget {
  final Function(FamilyModel newFamily) onSuccess;

  const _CreateFamilyBottomSheet({required this.onSuccess});

  @override
  State<_CreateFamilyBottomSheet> createState() => _CreateFamilyBottomSheetState();
}

class _CreateFamilyBottomSheetState extends State<_CreateFamilyBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _originController = TextEditingController();
  final _descController = TextEditingController();
  final _joinCodeController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _originController.dispose();
    _descController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final family = await FamilyApiService.createFamily(
        name: _nameController.text.trim(),
        originLocation: _originController.text.trim(),
        description: _descController.text.trim(),
        joinCode: _joinCodeController.text.trim(),
      );

      widget.onSuccess(family);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDD2C4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E7DC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.park_rounded, color: Color(0xFF6B3E1E)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tạo gia phả mới',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D1C10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tên gia phả
              const Text(
                'Tên dòng họ / Gia phả *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D1C10)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Gia phả Họ Nguyễn - Chi 3',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên dòng họ / gia phả';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Quê quán / Nguồn gốc
              const Text(
                'Quê quán / Nguồn gốc (Tùy chọn)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D1C10)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _originController,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Nam Định, Việt Nam',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Mã tham gia tùy chọn
              const Text(
                'Mã tham gia tùy chọn (Để trống sẽ tự sinh)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D1C10)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: NGUYEN88',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Mô tả / Lời ngỏ
              const Text(
                'Mô tả / Lời ngỏ gia phả (Tùy chọn)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D1C10)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Giới thiệu sơ lược về nguồn gốc tổ tiên, truyền thống dòng họ...',
                  filled: true,
                  fillColor: const Color(0xFFFAF7F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5DCD3)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nút Tạo gia phả
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B3E1E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Tạo gia phả ngay',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
