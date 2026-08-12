import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';

// Import 3 màn hình thêm mới
import 'add_income_screen.dart';
import 'add_expense_screen.dart';
import 'add_merit_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Thêm Listener để cập nhật lại nút bấm khi người dùng chuyển Tab
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 1. Khối Tổng quan (Tổng thu, Tổng chi, Số dư)
          _buildOverviewCard(),

          // 2. Ô Tìm kiếm & Lọc thời gian
          _buildSearchAndFilterRow(),

          const SizedBox(height: 12),

          // 3. Thanh TabBar chuyển tab
          _buildTabBar(),

          const SizedBox(height: 8),

          // 4. Nội dung danh sách theo từng Tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllTransactionsTab(), // Tab 0: Tất cả
                _buildIncomeTab(), // Tab 1: Thu
                _buildExpenseTab(), // Tab 2: Chi
                _buildMeritTab(), // Tab 3: Công đức
              ],
            ),
          ),
        ],
      ),
      // Nút bấm nổi CỐ ĐỊNH ở đáy màn hình, không bị trôi khi cuộn
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // ===========================================================================
  // NÚT BẤM NỔI CỐ ĐỊNH THEO TỪNG TAB
  // ===========================================================================
  Widget? _buildFloatingActionButton() {
    // Tab 0 ("Tất cả"): Không hiện nút thêm
    if (_tabController.index == 0) return null;

    String label = '';
    VoidCallback? onTap;

    if (_tabController.index == 1) {
      label = 'Thêm khoản thu';
      onTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddIncomeScreen()),
      );
    } else if (_tabController.index == 2) {
      label = 'Thêm khoản chi';
      onTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
      );
    } else if (_tabController.index == 3) {
      label = 'Thêm khoản công đức';
      onTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddMeritScreen()),
      );
    }

    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: AppColors.primary,
      elevation: 3,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thu Chi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Quản lý các khoản thu chi của gia Phả',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. TỔNG QUAN THU CHI (ĐÃ CÓ VẠCH PHÂN CÁCH)
  // ===========================================================================
  Widget _buildOverviewCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Expanded(
            child: _OverviewItem(
              label: 'Tổng thu',
              amount: '450.060.000 đ',
              color: Color(0xFF2E7D32),
            ),
          ),
          // Vạch phân cách 1
          Container(height: 24, width: 1, color: AppColors.border),
          const Expanded(
            child: _OverviewItem(
              label: 'Tổng chi',
              amount: '340.060.000 đ',
              color: Color(0xFFD32F2F),
            ),
          ),
          // Vạch phân cách 2
          Container(height: 24, width: 1, color: AppColors.border),
          const Expanded(
            child: _OverviewItem(
              label: 'Số dư',
              amount: '110.060.000 đ',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. TÌM KIẾM & BỘ LỌC
  // ===========================================================================
  Widget _buildSearchAndFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm giao dịch',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Text(
                  '12/02/2026-18/02/2026',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primaryMedium,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. TABBAR
  // ===========================================================================
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF2ECE4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Tất cả'),
          Tab(text: 'Thu'),
          Tab(text: 'Chi'),
          Tab(text: 'Công đức'),
        ],
      ),
    );
  }
  // ===========================================================================
  // 4. DANH SÁCH CHO TỪNG TAB
  // ===========================================================================

  // Tab 0: Tất cả
  Widget _buildAllTransactionsTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
      children: [
        _buildDateGroup(
          dateText: 'Hôm nay - 29/04/2024',
          totalIncome: '+2.500.000 đ',
          totalExpense: '-1.200.000 đ',
          items: [_buildItemBuilding(), _buildItemMaterial()],
        ),
        _buildDateGroup(
          dateText: '28/04/2024',
          totalIncome: '+1.500.000 đ',
          totalExpense: '-500.000 đ',
          items: [_buildItemBirthday(), _buildItemParty()],
        ),
        _buildDateGroup(
          dateText: '27/04/2024',
          totalIncome: '+5.000.000 đ',
          totalExpense: '0 đ',
          items: [_buildItemScholarship()],
        ),
        _buildDateGroup(
          dateText: '25/04/2024',
          totalIncome: '0 đ',
          totalExpense: '-2.000.000 đ',
          items: [_buildItemDocument()],
        ),
        _buildDateGroup(
          dateText: '24/04/2024',
          totalIncome: '+1.000.000 đ',
          totalExpense: '0 đ',
          items: [_buildItemMerit()],
        ),
      ],
    );
  }

  // Tab 1: Thu
  Widget _buildIncomeTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
      children: [
        _buildDateGroup(
          dateText: 'Hôm nay - 29/04/2024',
          totalIncome: '+2.000.000 đ',
          totalExpense: '0 đ',
          items: [_buildItemBuilding()],
        ),
        _buildDateGroup(
          dateText: '28/04/2024',
          totalIncome: '+1.500.000 đ',
          totalExpense: '0 đ',
          items: [_buildItemBirthday()],
        ),
        _buildDateGroup(
          dateText: '27/04/2024',
          totalIncome: '+5.000.000 đ',
          totalExpense: '0 đ',
          items: [_buildItemScholarship()],
        ),
      ],
    );
  }

  // Tab 2: Chi
  Widget _buildExpenseTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
      children: [
        _buildDateGroup(
          dateText: 'Hôm nay - 29/04/2024',
          totalIncome: '0 đ',
          totalExpense: '-1.200.000 đ',
          items: [_buildItemMaterial()],
        ),
        _buildDateGroup(
          dateText: '28/04/2024',
          totalIncome: '0 đ',
          totalExpense: '-500.000 đ',
          items: [_buildItemParty()],
        ),
        _buildDateGroup(
          dateText: '25/04/2024',
          totalIncome: '0 đ',
          totalExpense: '-2.000.000 đ',
          items: [_buildItemDocument()],
        ),
      ],
    );
  }

  // Tab 3: Công đức
  Widget _buildMeritTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
      children: [
        _buildDateGroup(
          dateText: '24/04/2024',
          totalIncome: '+1.000.000 đ',
          totalExpense: '0 đ',
          items: [_buildItemMerit()],
        ),
      ],
    );
  }

  // ===========================================================================
  // MẪU ITEM GIAO DỊCH DÙNG CHUNG
  // ===========================================================================
  Widget _buildItemBuilding() {
    return const _TransactionItem(
      icon: Icons.card_giftcard_rounded,
      iconBgColor: Color(0xFFE8F5E9),
      iconColor: Color(0xFF2E7D32),
      title: 'Đóng góp xây dựng nhà thờ họ',
      subtitle: 'Nguyễn Văn A',
      amount: '+2.000.000 đ',
      category: 'Đóng góp',
      isIncome: true,
    );
  }

  Widget _buildItemMaterial() {
    return const _TransactionItem(
      icon: Icons.shopping_basket_outlined,
      iconBgColor: Color(0xFFFFEBEE),
      iconColor: Color(0xFFD32F2F),
      title: 'Mua vật tư xây dựng',
      subtitle: 'Trần Văn B',
      amount: '-1.200.000 đ',
      category: 'Chi xây dựng',
      isIncome: false,
    );
  }

  Widget _buildItemBirthday() {
    return const _TransactionItem(
      icon: Icons.card_giftcard_rounded,
      iconBgColor: Color(0xFFE8F5E9),
      iconColor: Color(0xFF2E7D32),
      title: 'Lì xì mừng thọ cụ Nguyễn Văn C',
      subtitle: 'Phạm Thị D',
      amount: '+1.500.000 đ',
      category: 'Mừng thọ',
      isIncome: true,
    );
  }

  Widget _buildItemParty() {
    return const _TransactionItem(
      icon: Icons.restaurant_outlined,
      iconBgColor: Color(0xFFFFEBEE),
      iconColor: Color(0xFFD32F2F),
      title: 'Tiệc mừng thọ',
      subtitle: 'Ban tổ chức',
      amount: '-500.000 đ',
      category: 'Chi mừng thọ',
      isIncome: false,
    );
  }

  Widget _buildItemScholarship() {
    return const _TransactionItem(
      icon: Icons.groups_outlined,
      iconBgColor: Color(0xFFE8F5E9),
      iconColor: Color(0xFF2E7D32),
      title: 'Đóng góp quỹ khuyến học',
      subtitle: 'Nhiều thành viên',
      amount: '+5.000.000 đ',
      category: 'Quỹ khuyến học',
      isIncome: true,
    );
  }

  Widget _buildItemDocument() {
    return const _TransactionItem(
      icon: Icons.description_outlined,
      iconBgColor: Color(0xFFFFEBEE),
      iconColor: Color(0xFFD32F2F),
      title: 'Chi phí in ấn tài liệu',
      subtitle: 'Nguyễn Văn E',
      amount: '-2.000.000 đ',
      category: 'Chi khác',
      isIncome: false,
    );
  }

  Widget _buildItemMerit() {
    return const _TransactionItem(
      icon: Icons.spa_outlined,
      iconBgColor: Color(0xFFFFF8E1),
      iconColor: Color(0xFFF57F17),
      title: 'Công đức tu bổ nhà thờ',
      subtitle: 'Lê Thị F',
      amount: '+1.000.000 đ',
      category: 'Công đức',
      isIncome: true,
    );
  }

  // ===========================================================================
  // WIDGET BỔ TRỢ (GROUP NGÀY)
  // ===========================================================================
  Widget _buildDateGroup({
    required String dateText,
    required String totalIncome,
    required String totalExpense,
    required List<Widget> items,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Thu: $totalIncome',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chi: $totalExpense',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ...items,
        const SizedBox(height: 8),
      ],
    );
  }
}

// ===========================================================================
// SUB-WIDGETS
// ===========================================================================
class _OverviewItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _OverviewItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final String category;
  final bool isIncome;

  const _TransactionItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.category,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isIncome
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFD32F2F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.more_vert_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}
