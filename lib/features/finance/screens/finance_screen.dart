import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import 'package:gentree/features/finance/models/transaction_model.dart';

// Import model của bạn (Thay đổi đường dẫn file này cho đúng vị trí trong dự án của bạn)

// Import các màn hình thêm mới
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
  final TextEditingController _searchController = TextEditingController();

  // Từ khóa tìm kiếm hiện tại
  String _searchQuery = '';

  // Biến lưu khoảng ngày được chọn
  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime(2026, 2, 12),
    end: DateTime(2026, 2, 18),
  );

  // Danh sách dữ liệu sử dụng Model thực tế của bạn
  List<TransactionModel> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _initSampleData(); // Khởi tạo dữ liệu mẫu theo Model chuẩn

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Lắng nghe sự thay đổi của ô tìm kiếm để lọc Real-time
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Khởi tạo danh sách mẫu đúng chuẩn TransactionModel của bạn
  void _initSampleData() {
    _allTransactions = [
      TransactionModel(
        id: '1',
        title: 'Đóng góp xây dựng nhà thờ họ',
        amount: 2000000,
        type: TransactionType.income,
        personName: 'Nguyễn Văn A',
        category: 'Đóng góp',
        date: DateTime(2024, 4, 29),
      ),
      TransactionModel(
        id: '2',
        title: 'Mua vật tư xây dựng',
        amount: 1200000,
        type: TransactionType.expense,
        personName: 'Trần Văn B',
        category: 'Chi xây dựng',
        date: DateTime(2024, 4, 29),
      ),
      TransactionModel(
        id: '3',
        title: 'Lì xì mừng thọ cụ Nguyễn Văn C',
        amount: 1500000,
        type: TransactionType.income,
        personName: 'Phạm Thị D',
        category: 'Mừng thọ',
        date: DateTime(2024, 4, 28),
      ),
      TransactionModel(
        id: '4',
        title: 'Tiệc mừng thọ',
        amount: 500000,
        type: TransactionType.expense,
        personName: 'Ban tổ chức',
        category: 'Chi mừng thọ',
        date: DateTime(2024, 4, 28),
      ),
      TransactionModel(
        id: '5',
        title: 'Đóng góp quỹ khuyến học',
        amount: 5000000,
        type: TransactionType.income,
        personName: 'Nhiều thành viên',
        category: 'Quỹ khuyến học',
        date: DateTime(2024, 4, 27),
      ),
      TransactionModel(
        id: '6',
        title: 'Chi phí in ấn tài liệu',
        amount: 2000000,
        type: TransactionType.expense,
        personName: 'Nguyễn Văn E',
        category: 'Chi khác',
        date: DateTime(2024, 4, 25),
      ),
      TransactionModel(
        id: '7',
        title: 'Công đức tu bổ nhà thờ',
        amount: 1000000,
        type: TransactionType.merit,
        personName: 'Lê Thị F',
        category: 'Công đức',
        date: DateTime(2024, 4, 24),
      ),
    ];
  }

  // Lọc danh sách giao dịch dựa trên Tab hiện tại & Từ khóa tìm kiếm
  List<TransactionModel> _getFilteredTransactions(int tabIndex) {
    return _allTransactions.where((item) {
      // 1. Lọc theo Tab bằng Enum TransactionType
      bool matchesTab = true;
      if (tabIndex == 1) {
        matchesTab = item.type == TransactionType.income;
      } else if (tabIndex == 2) {
        matchesTab = item.type == TransactionType.expense;
      } else if (tabIndex == 3) {
        matchesTab = item.type == TransactionType.merit;
      }

      // 2. Lọc theo từ khóa tìm kiếm
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = item.title.toLowerCase().contains(query);
        final personMatch = item.personName.toLowerCase().contains(query);
        final categoryMatch = item.category.toLowerCase().contains(query);
        final noteMatch = item.note?.toLowerCase().contains(query) ?? false;

        matchesSearch = titleMatch || personMatch || categoryMatch || noteMatch;
      }

      return matchesTab && matchesSearch;
    }).toList();
  }

  // Format số tiền double thành dạng chuỗi tiền tệ VND (VD: 2000000 -> 2.000.000 đ)
  String _formatCurrency(double amount) {
    final String numStr = amount.toInt().toString();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final String formatted = numStr.replaceAllMapped(
      reg,
      (Match m) => '${m[1]}.',
    );
    return '$formatted đ';
  }

  // Format ngày dd/MM/yyyy
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  // Tên nhóm ngày (VD: Hôm nay - 29/04/2024)
  String _getDateGroupTitle(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hôm nay - ${_formatDate(date)}';
    }
    return _formatDate(date);
  }

  // Sự kiện chọn lịch
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // Hiển thị Thông báo
  void _showNotificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Thông báo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildNotificationItem(
                      title: 'Xác nhận khoản đóng góp mới',
                      time: '10 phút trước',
                      content:
                          'Nguyễn Văn A đã đóng góp 2.000.000 đ vào quỹ xây dựng.',
                      isUnread: true,
                    ),
                    _buildNotificationItem(
                      title: 'Duyệt khoản chi',
                      time: '2 giờ trước',
                      content:
                          'Khoản chi "Mua vật tư xây dựng" đã được quản trị viên duyệt.',
                      isUnread: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String time,
    required String content,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isUnread ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Xóa giao dịch
  void _deleteTransaction(String id) {
    setState(() {
      _allTransactions.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 1. Khối Tổng quan
          _buildOverviewCard(),

          // 2. Ô Tìm kiếm & Bộ lọc ngày
          _buildSearchAndFilterRow(),

          const SizedBox(height: 12),

          // 3. TabBar
          _buildTabBar(),

          const SizedBox(height: 8),

          // 4. Danh sách giao dịch
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionListByTab(0),
                _buildTransactionListByTab(1),
                _buildTransactionListByTab(2),
                _buildTransactionListByTab(3),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

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
          onPressed: _showNotificationSheet,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          onSelected: (value) {},
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Hồ sơ cá nhân',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Đăng xuất',
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
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

  Widget _buildOverviewCard() {
    // Tính toán tổng số tiền
    double totalIncome = 0;
    double totalExpense = 0;

    for (var item in _allTransactions) {
      if (item.type == TransactionType.income ||
          item.type == TransactionType.merit) {
        totalIncome += item.amount;
      } else if (item.type == TransactionType.expense) {
        totalExpense += item.amount;
      }
    }

    final double balance = totalIncome - totalExpense;

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
          Expanded(
            child: _OverviewItem(
              label: 'Tổng thu',
              amount: _formatCurrency(totalIncome),
              color: const Color(0xFF2E7D32),
            ),
          ),
          Container(height: 24, width: 1, color: AppColors.border),
          Expanded(
            child: _OverviewItem(
              label: 'Tổng chi',
              amount: _formatCurrency(totalExpense),
              color: const Color(0xFFD32F2F),
            ),
          ),
          Container(height: 24, width: 1, color: AppColors.border),
          Expanded(
            child: _OverviewItem(
              label: 'Số dư',
              amount: _formatCurrency(balance),
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    final String dateRangeText = _selectedDateRange != null
        ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
        : 'Chọn khoảng ngày';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Ô Tìm kiếm
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus();
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
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
                  if (_searchQuery.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.clear_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _searchQuery = _searchController.text.trim();
                      });
                    },
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút chọn ngày
          InkWell(
            onTap: _selectDateRange,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    dateRangeText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.primaryMedium,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTransactionListByTab(int tabIndex) {
    final filteredList = _getFilteredTransactions(tabIndex);

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Không tìm thấy giao dịch phù hợp với "$_searchQuery"'
                  : 'Không có dữ liệu giao dịch',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    // Nhóm giao dịch theo Ngày
    final Map<String, List<TransactionModel>> groupedTransactions = {};
    for (var item in filteredList) {
      final dateKey = _getDateGroupTitle(item.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(item);
    }

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
      children: groupedTransactions.entries.map((entry) {
        final dateGroupText = entry.key;
        final items = entry.value;

        double sumIncome = 0;
        double sumExpense = 0;

        for (var item in items) {
          if (item.type == TransactionType.income ||
              item.type == TransactionType.merit) {
            sumIncome += item.amount;
          } else {
            sumExpense += item.amount;
          }
        }

        return _buildDateGroup(
          dateText: dateGroupText,
          totalIncome: sumIncome > 0 ? '+${_formatCurrency(sumIncome)}' : '0 đ',
          totalExpense: sumExpense > 0
              ? '-${_formatCurrency(sumExpense)}'
              : '0 đ',
          items: items.map((item) {
            return _TransactionItem(
              item: item,
              formatCurrency: _formatCurrency,
              formatDate: _formatDate,
              onDelete: () => _deleteTransaction(item.id),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

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
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionModel item;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final VoidCallback onDelete;

  const _TransactionItem({
    required this.item,
    required this.formatCurrency,
    required this.formatDate,
    required this.onDelete,
  });

  // Chọn màu sắc và Icon tương ứng theo TransactionType
  IconData _getIcon() {
    switch (item.type) {
      case TransactionType.income:
        return Icons.card_giftcard_rounded;
      case TransactionType.expense:
        return Icons.shopping_basket_outlined;
      case TransactionType.merit:
        return Icons.spa_outlined;
      default:
        return Icons.attach_money_rounded;
    }
  }

  Color _getIconBgColor() {
    switch (item.type) {
      case TransactionType.income:
        return const Color(0xFFE8F5E9);
      case TransactionType.expense:
        return const Color(0xFFFFEBEE);
      case TransactionType.merit:
        return const Color(0xFFFFF8E1);
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getIconColor() {
    switch (item.type) {
      case TransactionType.income:
        return const Color(0xFF2E7D32);
      case TransactionType.expense:
        return const Color(0xFFD32F2F);
      case TransactionType.merit:
        return const Color(0xFFF57F17);
      default:
        return Colors.black;
    }
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xóa sự kiện',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bạn có chắc chắn muốn xóa sự kiện này không?',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF3EC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF0E4D7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${item.personName} • ${formatDate(item.date)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Hành động này không thể được hoàn tác.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        onDelete();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDE3B40),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Xóa',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPositive =
        item.type == TransactionType.income ||
        item.type == TransactionType.merit;
    final String sign = isPositive ? '+' : '-';
    final String formattedAmount = '$sign${formatCurrency(item.amount)}';

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
              color: _getIconBgColor(),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIcon(), color: _getIconColor(), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.personName,
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
                formattedAmount,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isPositive
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFD32F2F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.category,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            offset: const Offset(0, 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: const Color(0xFFFAF3EC),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                height: 38,
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Sửa',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem<String>(
                value: 'delete',
                height: 38,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Xóa',
                      style: TextStyle(fontSize: 13.5, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
