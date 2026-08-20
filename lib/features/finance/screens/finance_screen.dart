import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../../auth/models/auth_request_model.dart';
import '../../auth/services/auth_service.dart';
import '../../family/models/family_model.dart';
import '../../family/services/family_api_service.dart';
import '../models/transaction_model.dart';
import '../services/finance_api_service.dart';
import '../widgets/finance_summary_card.dart';
import '../widgets/finance_tab_bar.dart';
import '../widgets/transaction_card.dart';

// Import màn hình thêm mới
import 'add_transaction_screen.dart';

class FinanceScreen extends StatefulWidget {
  final int? familyId;

  const FinanceScreen({super.key, this.familyId});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;

  UserModel? _currentUser;
  FamilyModel? _currentFamily;
  int? _activeFamilyId;

  List<TransactionModel> _allTransactions = [];
  FinanceSummaryModel _summary = FinanceSummaryModel.empty();

  // ==================== PHÂN QUYỀN TRƯỞNG HỌ & EDITOR ====================
  bool get _isAdmin {
    final famRole = _currentFamily?.userRole;
    final userRole = _currentUser?.role;
    final String role = (famRole ?? userRole ?? 'member').toLowerCase();
    if (role == 'admin' || role == 'owner') return true;
    if (_currentFamily?.ownerId != null &&
        _currentUser?.id != null &&
        _currentFamily!.ownerId == _currentUser!.id) {
      return true;
    }
    return false;
  }

  bool get _isEditor {
    final famRole = _currentFamily?.userRole;
    final userRole = _currentUser?.role;
    final String role = (famRole ?? userRole ?? 'member').toLowerCase();
    return role == 'editor';
  }

  bool get _canManage => _isAdmin || _isEditor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _activeFamilyId = widget.familyId;

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });

    _loadUserAndFamily();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndFamily() async {
    final user = await AuthService.getSavedUser();
    final family = await FamilyApiService.getCurrentFamily();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _currentFamily = family;
        if (_activeFamilyId == null && family != null) {
          _activeFamilyId = family.id;
        }
      });
      _loadFinanceData();
    }
  }

  Future<void> _loadFinanceData() async {
    if (_activeFamilyId == null) {
      final family = await FamilyApiService.getCurrentFamily();
      if (family != null) {
        _activeFamilyId = family.id;
        _currentFamily = family;
      }
    }

    setState(() => _isLoading = true);

    try {
      final transactions = await FinanceApiService.getTransactions(
        familyId: _activeFamilyId,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        search: _searchQuery,
      );

      FinanceSummaryModel summary = FinanceSummaryModel.empty();
      if (_activeFamilyId != null) {
        summary = await FinanceApiService.getFinanceSummary(_activeFamilyId!);
      }

      if (mounted) {
        setState(() {
          _allTransactions = transactions;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[!] Error loading finance data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

      // 3. Lọc theo khoảng ngày nếu có
      bool matchesDate = true;
      if (_selectedDateRange != null) {
        final start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );
        final end = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23,
          59,
          59,
        );
        matchesDate = !item.date.isBefore(start) && !item.date.isAfter(end);
      }

      return matchesTab && matchesSearch && matchesDate;
    }).toList();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _getDateGroupTitle(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hôm nay - ${_formatDate(date)}';
    }
    return _formatDate(date);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
      setState(() => _selectedDateRange = picked);
      _loadFinanceData();
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDateRange = null);
    _loadFinanceData();
  }

  Future<void> _handleApprove(TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận phê duyệt'),
        content: Text('Bạn có chắc muốn phê duyệt khoản "${tx.title}" (${tx.formattedAmount}) không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Phê duyệt', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await FinanceApiService.approveTransaction(tx.id);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã phê duyệt giao dịch thành công!'), backgroundColor: AppColors.success),
        );
        _loadFinanceData();
      }
    }
  }

  Future<void> _handleReject(TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Từ chối giao dịch'),
        content: Text('Bạn có chắc muốn từ chối khoản "${tx.title}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.badgeRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Từ chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await FinanceApiService.rejectTransaction(tx.id);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối giao dịch'), backgroundColor: AppColors.badgeRed),
        );
        _loadFinanceData();
      }
    }
  }

  Future<void> _handleDelete(TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa giao dịch "${tx.title}" không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.badgeRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await FinanceApiService.deleteTransaction(tx.id);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa giao dịch thành công')),
        );
        _loadFinanceData();
      }
    }
  }

  Future<void> _openAddTransactionScreen([TransactionType? type]) async {
    TransactionType initialType = type ?? TransactionType.income;
    if (type == null) {
      if (_tabController.index == 1) {
        initialType = TransactionType.income;
      } else if (_tabController.index == 2) {
        initialType = TransactionType.expense;
      } else if (_tabController.index == 3) {
        initialType = TransactionType.merit;
      } else {
        initialType = TransactionType.income;
      }
    }

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddTransactionScreen(
          canManage: _canManage,
          familyId: _activeFamilyId,
          initialType: initialType,
        ),
      ),
    );
    if (res == true) _loadFinanceData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddTransactionScreen(),
        backgroundColor: AppColors.primaryGold,
        elevation: 4,
        child: const Icon(Icons.add, color: AppColors.white, size: 28),
      ),
      body: Column(
        children: [
          // 1. Header AppBar
          _buildHeader(context),

          // 2. Nội dung Tab
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadFinanceData,
                    color: AppColors.primary,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabContent(0),
                        _buildTabContent(1),
                        _buildTabContent(2),
                        _buildTabContent(3),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Column(
        children: [
          // Tiêu đề & Icon chuông
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Text(
                'Thu chi & Quỹ họ',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
                onPressed: _loadFinanceData,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Ô tìm kiếm & Nút chọn ngày
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),                    
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Tìm kiếm khoản thu chi...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 40,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 40,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _selectDateRange,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _selectedDateRange != null
                        ? AppColors.primaryGold
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: _selectedDateRange != null
                            ? Colors.white
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedDateRange != null
                            ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                            : 'Chọn ngày',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedDateRange != null
                              ? Colors.white
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: _clearDateFilter,
                  child: const Text(
                    'Xóa lọc ngày ✕',
                    style: TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final filtered = _getFilteredTransactions(tabIndex);

    // Gom nhóm giao dịch theo ngày
    final Map<String, List<TransactionModel>> groupedTransactions = {};
    for (var item in filtered) {
      final key = _getDateGroupTitle(item.date);
      if (!groupedTransactions.containsKey(key)) {
        groupedTransactions[key] = [];
      }
      groupedTransactions[key]!.add(item);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Thẻ tổng kết Thu - Chi - Số dư
          FinanceSummaryCard(
            totalIncome: _summary.totalIncome + _summary.totalMerit,
            totalExpense: _summary.totalExpense,
          ),
          const SizedBox(height: 16),

          // Thanh chuyển Tab
          FinanceTabBar(
            controller: _tabController,
            onTap: (index) {
              setState(() {});
            },
          ),
          const SizedBox(height: 16),

          // Danh sách Giao dịch
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có giao dịch thu chi nào phù hợp',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...groupedTransactions.entries.map((entry) {
              return _buildDateGroup(entry.key, entry.value);
            }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDateGroup(String dateTitle, List<TransactionModel> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              dateTitle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                TransactionCard(
                  transaction: item,
                  canManage: _canManage,
                  onApprove: () => _handleApprove(item),
                  onReject: () => _handleReject(item),
                  onDelete: () => _handleDelete(item),
                ),
                if (index < items.length - 1)
                  const Divider(
                    height: 1,
                    indent: 68,
                    color: AppColors.border,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
