import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import 'package:gentree/features/event/models/event_model.dart';
import 'package:gentree/features/event/screens/event_screen.dart';
import 'package:gentree/features/finance/screens/finance_screen.dart';
import 'package:gentree/features/member/screens/member_list_screen.dart';
import '../../tree/screens/tree_screen.dart';


// Giả định bạn đã import các file này trong project:
// import 'app_colors.dart';
// import 'event_model.dart';
// import 'event_screen.dart';
// import 'member_list_screen.dart';
// import 'finance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomIndex = 0;
  bool _showRoleMenu = false;
  bool _isEventNotified = false;
  final List<EventModel> _events = EventModel.sampleEvents;

  // Lấy sự kiện đầu tiên làm sự kiện sắp tới (tránh lỗi null)
  EventModel? get _nextEvent => _events.isNotEmpty ? _events.first : null;

  void _onTabSelected(int index) {
    setState(() {
      _currentBottomIndex = index;
    });
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
        return _buildPlaceholderScreen('Nhận diện AI');
      case 3:
        return EventScreen(events: _events);
      case 4:
        return const FinanceScreen();
      default:
        return Stack(
          children: [
            // Nội dung chính cuộn dọc (Tab Trang chủ)
            SingleChildScrollView(
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
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.primaryDark,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào,',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Nguyễn Văn A',
                  style: TextStyle(
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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 55,
      right: 20,
      child: Container(
        width: 180,
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
              onTap: () => setState(() => _showRoleMenu = false),
            ),
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
              onTap: () => setState(() => _showRoleMenu = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. BANNER TIÊU ĐỀ GIA PHẢ HỌ NGUYỄN
  // ===========================================================================
  Widget _buildFamilyBannerTitle() {
    return Column(
      children: [
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
            const Text(
              'Gia Phả Họ Nguyễn',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Serif',
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TreeScreen(),
                  ),
                );
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
  // 5. SECTION SỰ KIỆN SẮP TỚI
  // ===========================================================================
  Widget _buildUpcomingEventSection() {
    final event = _nextEvent;
    if (event == null) return const SizedBox.shrink();

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
        Container(
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
              // Khung ngày tháng -> Khớp getter trong EventModel
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
                      event.dayString, // Đã đổi từ dayLabel -> dayString
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.monthLabel, // Lấy "THÁNG XX"
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      event.yearLabel,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Colors.white70,
                      ),
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
                          event.time, // Đã đổi từ timeRange -> time
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
                          Icons
                              .notes_rounded, // Đổi icon địa điểm -> icon ghi chú
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.note.isNotEmpty
                                ? event.note
                                : event.dateRange, // Dùng note hoặc dateRange
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
        ),
      ],
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Thành viên',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt_rounded),
            label: 'Nhận diện AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Sự kiện',
          ),
          BottomNavigationBarItem(
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
