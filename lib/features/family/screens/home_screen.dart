import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import 'package:gentree/features/event/models/event_model.dart';
import 'package:gentree/features/event/screens/event_screen.dart';
import 'package:gentree/features/event/services/event_api_service.dart';
import 'package:gentree/features/finance/screens/finance_screen.dart';
import 'package:gentree/features/member/screens/member_list_screen.dart';
import '../../tree/screens/tree_screen.dart';
import '../../auth/models/auth_request_model.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../member/repositories/member_repository.dart';
import '../models/family_model.dart';
import '../services/family_api_service.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../admin/services/admin_api_service.dart';
import '../../face_recognition/screens/face_scanner_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomIndex = 0;
  bool _showRoleMenu = false;
  bool _isEventNotified = false;
  List<EventModel> _events = [];
  UserModel? _currentUser;
  FamilyModel? _currentFamily;
  List<FamilyModel> _myFamilies = [];
  String _currentBranch = 'Họ nội';
  int _totalAdminPendingCount = 0;
  final GlobalKey<FaceScannerScreenState> _faceScannerKey = GlobalKey<FaceScannerScreenState>();


  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadFamilyData();
  }

  Future<void> _loadCurrentUser() async {
    final cached = await AuthService.getSavedUser();
    if (mounted && cached != null) {
      setState(() {
        _currentUser = cached;
      });
    }
    final fresh = await AuthService.fetchProfile();
    if (mounted && fresh != null) {
      setState(() {
        _currentUser = fresh;      });
    }
  }

  Future<void> _loadAdminStats() async {
    final familyId = _currentFamily?.id;
    if (familyId == null) return;
    try {
      final stats = await AdminApiService.getDashboardStats(familyId);
      if (mounted) {
        setState(() {
          _totalAdminPendingCount = stats.pendingApprovals;
        });
      }
    } catch (e) {
      debugPrint('[!] Error loading admin stats on HomeScreen: $e');
    }
  }

  Future<void> _loadFamilyData() async {
    final cached = await FamilyApiService.getCurrentFamily();
    final families = await FamilyApiService.getMyFamilies();
    if (!mounted) return;

    setState(() {
      _myFamilies = families;
      if (cached != null && families.any((f) => f.id == cached.id)) {
        _currentFamily = families.firstWhere((f) => f.id == cached.id);
      } else if (families.isNotEmpty) {
        _currentFamily = families.first;
        FamilyApiService.saveCurrentFamily(_currentFamily!);
      }

      // Xác định tên nhánh: nếu có từ 2 gia phả trở lên
      if (_myFamilies.length >= 2) {
        if (_currentFamily != null && _currentFamily!.id == _myFamilies[1].id) {
          _currentBranch = 'Họ ngoại';
        } else {
          _currentBranch = 'Họ nội';
        }
      } else {
        _currentBranch = 'Họ nội';
      }
    });

    await _loadUpcomingEvents();
    await _loadAdminStats();
  }

  Future<void> _loadUpcomingEvents() async {
    final familyId = _currentFamily?.id;
    try {
      final events = await EventApiService.getEvents(
        familyId: familyId,
        autoSync: true,
      );
      if (mounted) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final upcoming = events.where((e) {
          final date = e.solarDate ?? e.date;
          final d = DateTime(date.year, date.month, date.day);
          return !d.isBefore(today);
        }).toList();
        upcoming.sort(
          (a, b) => (a.solarDate ?? a.date).compareTo(b.solarDate ?? b.date),
        );

        final past = events.where((e) {
          final date = e.solarDate ?? e.date;
          final d = DateTime(date.year, date.month, date.day);
          return d.isBefore(today);
        }).toList();
        past.sort(
          (a, b) => (b.solarDate ?? b.date).compareTo(a.solarDate ?? a.date),
        );

        setState(() {
          _events = [...upcoming, ...past];
        });
      }
    } catch (e) {
      debugPrint('[!] Error loading events on HomeScreen: $e');
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _showRoleMenu = false);
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
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.badgeRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

  void _onTabSelected(int index) {
    if (index == 2 && _currentBottomIndex == 2) {
      _faceScannerKey.currentState?.captureAndScan();
      return;
    }
    setState(() {
      _currentBottomIndex = index;
    });
    if (index == 0) {
      _loadUpcomingEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(top: false, child: _buildPageContent()),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildPageContent() {
    switch (_currentBottomIndex) {
      case 1:
        return const MemberListScreen();
      case 2:
        return FaceScannerScreen(
          key: _faceScannerKey,
          onBack: () {
            setState(() {
              _currentBottomIndex = 0;
            });
          },
        );      case 3:
        return EventScreen(events: _events);
      case 4:
        return const FinanceScreen();
      default:
        return Stack(
          children: [
            // Nội dung chính cuộn dọc (Tab Trang chủ)
            RefreshIndicator(
              onRefresh: () async {
                await _loadCurrentUser();
                await _loadFamilyData();
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 1. Header màu nâu đậm chào mừng người dùng
                    _buildHeaderSection(),

                    const SizedBox(height: 16),

                    // 2. Banner Tiêu đề Gia phả dòng họ
                    _buildFamilyBannerTitle(),

                    const SizedBox(height: 20),

                    // 3. Grid Lối tắt Thao tác nhanh
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildQuickActionsGrid(),
                    ),

                    const SizedBox(height: 20),

                    // 4. Banner Xác thực thành viên bằng AI
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildAiVerificationBanner(),
                    ),

                    const SizedBox(height: 20),

                    // 5. Section Sự kiện sắp tới
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildUpcomingEventSection(),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Popup menu tùy chọn Role (Quản trị, Hồ sơ cá nhân, Đăng xuất)
            if (_showRoleMenu) _buildRolePopupMenu(),
          ],
        );
    }
  }

  Widget _buildPlaceholderScreen(String title) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 14,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.more_horiz_rounded, color: Colors.white),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Trang $title đang được phát triển.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. HEADER SECTION (AppBar màu nâu đậm)
  // ===========================================================================
  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: AppColors.surfaceWarm,
            ),
              child: ClipOval(
              child: _currentUser?.resolvedAvatarUrl != null &&
                      _currentUser!.resolvedAvatarUrl!.isNotEmpty
                  ? Image.network(
                      _currentUser!.resolvedAvatarUrl!,
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      errorBuilder: (context, error, stack) => const Icon(              Icons.person_outline_rounded,
              color: AppColors.primaryDark,
              size: 28,
              ),
                    )
                  : const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primaryDark,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xin chào,',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentUser?.displayName ?? 'Nguyễn Văn A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

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
                  onPressed: () {},
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _showRoleMenu = !_showRoleMenu;
                        });
                      },
                    ),
                    if (_totalAdminPendingCount > 0 &&
                        (_currentFamily?.userRole == 'owner' ||
                            _currentFamily?.userRole == 'admin' ||
                            (_currentFamily?.ownerId != null &&
                                _currentUser?.id != null &&
                                _currentFamily!.ownerId == _currentUser!.id)))
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.badgeRed,
                            shape: BoxShape.circle,
                          ),
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

  // ===========================================================================
  // POPUP MENU CHO ROLE
  // ===========================================================================
  Widget _buildRolePopupMenu() {
    final bool isAdmin =
        _currentFamily?.userRole == 'owner' ||
        _currentFamily?.userRole == 'admin' ||
        (_currentFamily?.ownerId != null &&
            _currentUser?.id != null &&
            _currentFamily!.ownerId == _currentUser!.id);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 55,
      right: 20,
      child: Container(
        width: 195,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              icon: Icons.shield_outlined,
              text: 'Quản trị',
              textColor: AppColors.textPrimary,
              badgeCount: isAdmin ? _totalAdminPendingCount : 0,
              onTap: () async {
                setState(() => _showRoleMenu = false);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) =>
                        AdminDashboardScreen(familyId: _currentFamily?.id),
                  ),
                );
                _loadAdminStats();
              },
            ),
            // Mục chỉnh sửa thông tin gia phả dành cho Admin/Owner
            if (isAdmin && _currentFamily != null) ...[
              const Divider(height: 1, color: AppColors.divider),
              _buildMenuItem(
                icon: Icons.edit_note_rounded,
                text: 'Chỉnh sửa gia phả',
                textColor: const Color(0xFF1E60B5),
                onTap: () {
                  setState(() => _showRoleMenu = false);
                  _showEditFamilyDialog();
                },
              ),
            ],

            const Divider(height: 1, color: AppColors.divider),
            _buildMenuItem(
              icon: Icons.person_outline_rounded,
              text: 'Hồ sơ cá nhân',
              textColor: AppColors.textPrimary,
              onTap: () => setState(() => _showRoleMenu = false),
            ),
            const Divider(height: 1, color: AppColors.divider),
            _buildMenuItem(
              icon: Icons.logout_rounded,
              text: 'Đăng xuất',
              textColor: AppColors.badgeRed,
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  /// Hộp thoại/BottomSheet chỉnh sửa thông tin gia phả
  void _showEditFamilyDialog() {
    if (_currentFamily == null) return;
    final nameCtrl = TextEditingController(text: _currentFamily!.name);
    final originCtrl = TextEditingController(
      text: _currentFamily!.originLocation ?? '',
    );
    final descCtrl = TextEditingController(
      text: _currentFamily!.description ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh kéo handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E7DC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Chỉnh sửa thông tin gia phả',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Mã gia phả (chỉ đọc)
                  if (_currentFamily!.joinCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.qr_code_rounded,
                            size: 20,
                            color: AppColors.primaryMedium,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Mã gia phả: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _currentFamily!.joinCode!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tên gia phả
                  const Text(
                    'Tên gia phả *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập tên gia phả (VD: Gia phả họ Nguyễn)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.family_restroom_rounded,
                        size: 20,
                        color: AppColors.primaryMedium,
                      ),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Vui lòng nhập tên gia phả'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Quê quán / Nguồn gốc
                  const Text(
                    'Quê quán / Nguồn gốc',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: originCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Nhập quê quán / nguyên quán (VD: Hà Tây, Nam Định)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: AppColors.primaryMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mô tả / Lời tựa
                  const Text(
                    'Giới thiệu / Lời tựa',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Nhập lời tựa hoặc giới thiệu về dòng họ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Nút Lưu thay đổi
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isSaving = true);
                              try {
                                final updated =
                                    await FamilyApiService.updateFamily(
                                      familyId: _currentFamily!.id!,
                                      name: nameCtrl.text.trim(),
                                      originLocation: originCtrl.text.trim(),
                                      description: descCtrl.text.trim(),
                                    );
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }
                                if (mounted && updated != null) {
                                  setState(() {
                                    _currentFamily = updated;
                                    final idx = _myFamilies.indexWhere(
                                      (f) => f.id == updated.id,
                                    );
                                    if (idx != -1) {
                                      _myFamilies[idx] = updated;
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã cập nhật gia phả: ${updated.name}',
                                      ),
                                      backgroundColor: AppColors.primaryDark,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  setSheetState(() => isSaving = false);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi cập nhật: $e'),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Lưu thay đổi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required Color textColor,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.badgeRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. BANNER TIÊU ĐỀ GIA PHẢ & CHUYỂN ĐỔI HỌ NỘI / NGOẠI
  // ===========================================================================
  Widget _buildFamilyBannerTitle() {
    final familyTitle = _currentFamily?.name.isNotEmpty == true
        ? _currentFamily!.name
        : 'Gia Phả Dòng Họ';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Nút chuyển đổi Họ nội / Họ ngoại ở góc phải phía trên tiêu đề
          Align(
            alignment: Alignment.topRight,
            child: InkWell(
              onTap: _handleBranchSwitch,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8D4B20),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentBranch,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Tên gia phả động
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '⤹ ☁ ',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  familyTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Serif',
                    color: AppColors.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                ' ☁ ⤸',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Giữ gìn truyền thống - Kết nối tương lai',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Xử lý bấm vào nút Họ nội / Họ ngoại
  void _handleBranchSwitch() {
    if (_myFamilies.length >= 2) {
      // Đã có cả 2 gia phả -> Tự động chuyển đổi giữa 2 bên
      setState(() {
        if (_currentFamily?.id == _myFamilies[0].id) {
          _currentFamily = _myFamilies[1];
          _currentBranch = 'Họ ngoại';
        } else {
          _currentFamily = _myFamilies[0];
          _currentBranch = 'Họ nội';
        }
      });
      FamilyApiService.saveCurrentFamily(_currentFamily!);
      MemberRepository.invalidateCache();
      _loadUpcomingEvents();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sync_alt_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đã chuyển sang $_currentBranch: ${_currentFamily?.name}',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      // Mới tham gia 1 bên -> Mở tùy chọn thêm nhánh còn lại
      final otherBranch = _currentBranch == 'Họ nội' ? 'Họ ngoại' : 'Họ nội';
      _showAddBranchOptionModal(otherBranch: otherBranch);
    }
  }

  /// Modal tùy chọn thêm nhánh gia phả thứ 2 (Họ ngoại / Họ nội)
  void _showAddBranchOptionModal({required String otherBranch}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E7DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF6B3E1E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thêm gia phả $otherBranch',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D1C10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Bạn hiện đang xem gia phả "${_currentFamily?.name ?? ''}" ($_currentBranch). Bạn muốn liên kết thêm gia phả $otherBranch?',
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF7D6E65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Nút Tạo gia phả mới
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5DCD3)),
              ),
              tileColor: const Color(0xFFFAF7F2),
              leading: const Icon(
                Icons.park_outlined,
                color: Color(0xFF6B3E1E),
              ),
              title: Text(
                'Tạo gia phả $otherBranch mới',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D1C10),
                ),
              ),
              subtitle: Text(
                'Tạo gia phả riêng cho dòng họ bên $otherBranch',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7D6E65)),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B3E1E),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateFamilyBranchModal(otherBranch);
              },
            ),
            const SizedBox(height: 12),

            // Nút Nhập mã gia phả có sẵn
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5DCD3)),
              ),
              tileColor: const Color(0xFFFAF7F2),
              leading: const Icon(
                Icons.people_alt_outlined,
                color: Color(0xFF6B3E1E),
              ),
              title: Text(
                'Nhập mã gia phả $otherBranch',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D1C10),
                ),
              ),
              subtitle: Text(
                'Nhập mã join code để tham gia gia phả $otherBranch đã có',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7D6E65)),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B3E1E),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showJoinFamilyBranchModal(otherBranch);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Modal tạo gia phả cho nhánh mới
  void _showCreateFamilyBranchModal(String branch) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final originCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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
                key: formKey,
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E7DC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.park_rounded,
                            color: Color(0xFF6B3E1E),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tạo gia phả $branch',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D1C10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tên dòng họ / Gia phả *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Gia phả $branch - Chi 1',
                        filled: true,
                        fillColor: const Color(0xFFFAF7F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tên gia phả'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Quê quán / Nguồn gốc',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: originCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Nam Định, Việt Nam',
                        filled: true,
                        fillColor: const Color(0xFFFAF7F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Mã tham gia tùy chọn',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: NGUYEN88 (Để trống tự sinh)',
                        filled: true,
                        fillColor: const Color(0xFFFAF7F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isCreating
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(ctx);
                                setModalState(() => isCreating = true);
                                try {
                                  final newFam =
                                      await FamilyApiService.createFamily(
                                        name: nameCtrl.text.trim(),
                                        originLocation: originCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                        joinCode: codeCtrl.text.trim(),
                                      );
                                  navigator.pop();
                                  await _loadFamilyData();
                                  if (mounted) {
                                    setState(() {
                                      _currentFamily = newFam;
                                      _currentBranch = branch;
                                    });
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã tạo và chuyển sang gia phả $branch: ${newFam.name}',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                } finally {
                                  setModalState(() => isCreating = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B3E1E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isCreating
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Tạo gia phả ngay',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Modal nhập mã tham gia cho nhánh mới
  void _showJoinFamilyBranchModal(String branch) {
    final codeCtrl = TextEditingController();
    bool isJoining = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            margin: EdgeInsets.only(bottom: bottomInset),
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E7DC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: Color(0xFF6B3E1E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tham gia gia phả $branch',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D1C10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mã gia phả *',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Nhập mã do quản trị viên cung cấp',
                    filled: true,
                    fillColor: const Color(0xFFFAF7F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isJoining
                        ? null
                        : () async {
                            final code = codeCtrl.text.trim();
                            if (code.isEmpty) return;
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            setModalState(() => isJoining = true);
                            try {
                              final result = await FamilyApiService.joinFamily(
                                joinCode: code,
                                branchType: branch,
                              );
                              navigator.pop();

                              if (result.requiresApproval ||
                                  result.family == null) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(result.message),
                                    backgroundColor: const Color(0xFFD97706),
                                  ),
                                );
                              } else {
                                await _loadFamilyData();
                                if (mounted) {
                                  setState(() {
                                    _currentFamily = result.family;
                                    _currentBranch = branch;
                                  });
                                }
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đã tham gia và chuyển sang gia phả $branch: ${result.family!.name}',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            } finally {
                              setModalState(() => isJoining = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B3E1E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isJoining
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Tham gia ngay',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 3. GRID THAO TÁC NHANH
  // ===========================================================================
  Widget _buildQuickActionsGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionItem(
              icon: Icons.park_outlined,
              title: 'Phả đồ',
              subtitle: 'Xem cây gia phả',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const TreeScreen()));
              },
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildActionItem(
              icon: Icons.groups_outlined,
              title: 'Thành viên',
              subtitle: 'Xem danh sách thành viên',
              onTap: () => _onTabSelected(1),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildActionItem(
              icon: Icons.calendar_month_outlined,
              title: 'Sự kiện',
              subtitle: 'Lịch và sự kiện',
              onTap: () => _onTabSelected(3),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildActionItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Thu chi',
              subtitle: 'Quản lý tài chính',
              onTap: () => _onTabSelected(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: AppColors.divider);
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceWarm,
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(icon, color: AppColors.primaryMedium, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. BANNER XÁC THỰC THÀNH VIÊN BẰNG AI
  // ===========================================================================
  Widget _buildAiVerificationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xác thực thành viên bằng AI',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chụp khuôn mặt để kiểm tra người này có thuộc dòng họ trong gia phả hay không.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _onTabSelected(2),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Mở Camera AI',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMedium,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 105,
                    height: 125,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E2723),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.face_retouching_natural_rounded,
                            color: AppColors.primaryGold,
                            size: 46,
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: CustomPaint(
                                painter: CameraCornerPainter(
                                  color: AppColors.primaryLightGold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. SECTION SỰ KIỆN SẮP TỚI (HIỂN THỊ 3 SỰ KIỆN GẦN NHẤT)
  // ===========================================================================
  Widget _buildUpcomingEventSection() {
    final upcomingEvents = _events.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.primaryMedium,
                ),
                SizedBox(width: 8),
                Text(
                  'Sự kiện sắp tới',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _onTabSelected(3),
              child: const Row(
                children: [
                  Text(
                    'Xem tất cả',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (upcomingEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarm,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primaryMedium,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Chưa có sự kiện nào sắp tới trong gia phả',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...upcomingEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildUpcomingEventCard(event),
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingEventCard(EventModel event) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Khung ngày tháng
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.dateBadge,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.dayString,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.monthLabel,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  event.yearLabel,
                  style: const TextStyle(fontSize: 8.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Thông tin sự kiện
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.time,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.note.isNotEmpty ? event.note : event.dateRange,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nút chuông thông báo
          InkWell(
            onTap: () {
              setState(() {
                _isEventNotified = !_isEventNotified;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isEventNotified
                    ? AppColors.surfaceWarm
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isEventNotified
                      ? AppColors.primaryGold
                      : AppColors.border,
                ),
              ),
              child: Icon(
                _isEventNotified
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: _isEventNotified
                    ? AppColors.primaryGold
                    : AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. BOTTOM NAVIGATION BAR
  // ===========================================================================
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentBottomIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        onTap: _onTabSelected,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Thành viên',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primaryExtraDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFFFFD580),
                size: 18,
              ),
            ),
            label: 'Nhận diện',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Sự kiện',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Thu chi',
          ),
        ],
      ),
    );
  }
}

class CameraCornerPainter extends CustomPainter {
  final Color color;

  CameraCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerLength = 10.0;

    // Góc trên - trái
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Góc trên - phải
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Góc dưới - trái
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );

    // Góc dưới - phải
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
