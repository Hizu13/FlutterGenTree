import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gentree/config/app_color.dart';
import '../../family/models/family_model.dart';
import '../../family/services/family_api_service.dart';
import '../../member/services/member_api_service.dart';
import '../../member/screens/add_member_screen.dart';
import '../../finance/screens/add_transaction_screen.dart';
import '../../finance/screens/finance_screen.dart';
import '../services/admin_api_service.dart';
import 'approval_list_screen.dart';
import 'event_approval_screen.dart';
import 'member_approval_screen.dart';
import 'role_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int? familyId;

  const AdminDashboardScreen({super.key, this.familyId});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  int? _activeFamilyId;
  FamilyModel? _currentFamily;
  AdminDashboardStats _stats = AdminDashboardStats.empty();

  @override
  void initState() {
    super.initState();
    _activeFamilyId = widget.familyId;
    _loadFamilyAndStats();
  }

  Future<void> _loadFamilyAndStats() async {
    setState(() => _isLoading = true);
    try {
      if (_activeFamilyId == null) {
        final family = await FamilyApiService.getCurrentFamily();
        if (family != null) {
          _currentFamily = family;
          _activeFamilyId = family.id;
        }
      }

      if (_activeFamilyId != null) {
        final stats = await AdminApiService.getDashboardStats(_activeFamilyId!);
        if (mounted) {
          setState(() {
            _stats = stats;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[!] Error loading admin stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImportExcel() async {
    if (_activeFamilyId == null) return;

    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        final fileName = result.first.name;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.table_chart_rounded, color: Color(0xFF1E7E34), size: 24),
                SizedBox(width: 8),
                Text('Xác nhận Import', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Bạn có muốn nhập dữ liệu gia phả từ tệp "$fileName" vào hệ thống không?',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E7E34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Bắt đầu Import', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Đang xử lý tệp Excel & đồng bộ...', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          );

          final res = await AdminApiService.importGenealogyExcel(
            familyId: _activeFamilyId!,
            file: file,
          );

          if (!mounted) return;
          Navigator.pop(context); // Đóng loading dialog

          if (res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['message'] ?? 'Import thành công!'),
                backgroundColor: AppColors.success,
              ),
            );
            _loadFamilyAndStats();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['message'] ?? 'Lỗi khi import file Excel'),
                backgroundColor: AppColors.badgeRed,
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn file: $e'), backgroundColor: AppColors.badgeRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quản trị',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_stats.familyName.isNotEmpty || _currentFamily?.name != null)
              Text(
                _stats.familyName.isNotEmpty ? _stats.familyName : (_currentFamily?.name ?? ''),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadFamilyAndStats,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= 1. SECTION TỔNG QUAN =================
                    const Text(
                      'Tổng quan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewGrid(),
                    const SizedBox(height: 24),

                    // ================= 2. SECTION THAO TÁC NHANH =================
                    const Text(
                      'Thao tác nhanh',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionsList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewGrid() {
    return Column(
      children: [
        Row(
          children: [
            // Thẻ 1: Tổng thành viên
            Expanded(
              child: _buildStatCard(
                icon: Icons.people_rounded,
                value: '${_stats.totalMembers}',
                label: 'Tổng thành viên',
              ),
            ),
            const SizedBox(width: 12),
            // Thẻ 2: Chờ duyệt (có badge đỏ)
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_month_outlined,
                value: '${_stats.pendingApprovals}',
                label: 'Chờ duyệt',
                badgeCount: _stats.pendingApprovals,
                onTap: () async {
                  if (_activeFamilyId != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => ApprovalListScreen(familyId: _activeFamilyId!),
                      ),
                    );
                    _loadFamilyAndStats();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Thẻ 3: Gia nhập mới (có badge đỏ)
            Expanded(
              child: _buildStatCard(
                icon: Icons.person_add_alt_1_rounded,
                value: '${_stats.newJoins}',
                label: 'Gia nhập mới',
                badgeCount: _stats.newJoins,
                onTap: () async {
                  if (_activeFamilyId != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => MemberApprovalScreen(familyId: _activeFamilyId!),
                      ),
                    );
                    _loadFamilyAndStats();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Thẻ 4: Số quỹ dư
            Expanded(
              child: _buildStatCard(
                icon: Icons.account_balance_wallet_rounded,
                value: _stats.formattedBalance,
                label: 'Số quỹ dư',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => FinanceScreen(familyId: _activeFamilyId),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    int? badgeCount,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 105,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF7F2), // Màu nền be ấm giống hệt thiết kế mẫu
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3E7DC), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: const Color(0xFF5A2E10), size: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.badgeRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsList() {
    return Column(
      children: [
        // 1. Duyệt sự kiện
        _buildActionTile(
          icon: Icons.event_available_outlined,
          title: 'Duyệt sự kiện',
          subtitle: '${_stats.pendingEvents} sự kiện đang chờ duyệt',
          badgeCount: _stats.pendingEvents,
          onTap: () async {
            if (_activeFamilyId != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => EventApprovalScreen(familyId: _activeFamilyId!),
                ),
              );
              _loadFamilyAndStats();
            }
          },
        ),
        const SizedBox(height: 10),

        // 2. Duyệt thành viên vào gia phả
        _buildActionTile(
          icon: Icons.how_to_reg_outlined,
          title: 'Duyệt thành viên vào gia phả',
          subtitle: '${_stats.newJoins} yêu cầu gia nhập chờ duyệt',
          badgeCount: _stats.newJoins,
          onTap: () async {
            if (_activeFamilyId != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => MemberApprovalScreen(familyId: _activeFamilyId!),
                ),
              );
              _loadFamilyAndStats();
            }
          },
        ),
        const SizedBox(height: 10),

        // 3. Duyệt thu/chi quỹ
        _buildActionTile(
          icon: Icons.fact_check_outlined,
          title: 'Duyệt thu/chi quỹ',
          subtitle: '${_stats.pendingTransactions} giao dịch quỹ chờ duyệt',
          badgeCount: _stats.pendingTransactions,
          onTap: () async {
            if (_activeFamilyId != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => ApprovalListScreen(familyId: _activeFamilyId!),
                ),
              );
              _loadFamilyAndStats();
            }
          },
        ),
        const SizedBox(height: 10),

        // 4. Thêm thành viên
        _buildActionTile(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Thêm thành viên',
          subtitle: 'Thêm thành viên mới vào gia phả',
          onTap: () async {
            final members = await MemberApiService.fetchAll(familyId: _activeFamilyId);
            if (!mounted) return;
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => AddMemberScreen(
                  existingMembers: members,
                  onSaved: (m) => _loadFamilyAndStats(),
                ),
              ),
            );
            if (res == true) _loadFamilyAndStats();
          },
        ),
        const SizedBox(height: 10),

        // 5. Ghi thu/chi quỹ
        _buildActionTile(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Ghi thu/chi quỹ',
          subtitle: 'Ghi nhận giao dịch mới',
          onTap: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => AddTransactionScreen(
                  canManage: true,
                  familyId: _activeFamilyId,
                ),
              ),
            );
            if (res == true) _loadFamilyAndStats();
          },
        ),
        const SizedBox(height: 10),

        // 6. Phân quyền thành viên
        _buildActionTile(
          icon: Icons.shield_rounded,
          title: 'Phân quyền thành viên',
          subtitle: 'Quản lý vai trò Editor/Member',
          onTap: () {
            if (_activeFamilyId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => RoleManagementScreen(familyId: _activeFamilyId!),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),

        // 7. Import gia phả bằng file Excel
        _buildActionTile(
          icon: Icons.file_upload_outlined,
          title: 'Nhập gia phả bằng file Excel',
          subtitle: 'Tải lên tệp .xlsx hoặc .xls',
          iconColor: const Color(0xFF2E7D32),
          onTap: _handleImportExcel,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF7F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3E7DC), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? const Color(0xFF5A2E10), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
