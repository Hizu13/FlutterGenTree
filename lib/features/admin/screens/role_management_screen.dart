import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../services/admin_api_service.dart';

class RoleManagementScreen extends StatefulWidget {
  final int familyId;

  const RoleManagementScreen({super.key, required this.familyId});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  bool _isLoading = false;
  List<AdminUserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final list = await AdminApiService.getFamilyUsers(widget.familyId);
    if (mounted) {
      setState(() {
        _users = list;
        _isLoading = false;
      });
    }
  }

  void _showChangeRoleDialog(AdminUserModel user) {
    String selectedRole = user.role.toLowerCase();
    if (!['admin', 'editor', 'member'].contains(selectedRole)) {
      selectedRole = 'member';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Phân quyền: ${user.fullName}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Quản trị viên (Admin)'),
                subtitle: const Text('Toàn quyền quản lý gia phả & phê duyệt'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              RadioListTile<String>(
                title: const Text('Biên tập viên (Editor)'),
                subtitle: const Text('Quyền thêm sửa sự kiện, thu chi'),
                value: 'editor',
                groupValue: selectedRole,
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              RadioListTile<String>(
                title: const Text('Thành viên (Member)'),
                subtitle: const Text('Chỉ xem và gửi yêu cầu phê duyệt'),
                value: 'member',
                groupValue: selectedRole,
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await AdminApiService.changeMemberRole(
                  userId: user.id,
                  familyId: widget.familyId,
                  newRole: selectedRole,
                );
                if (mounted) {
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã đổi vai trò của "${user.fullName}" thành "$selectedRole"'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    _loadUsers();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lỗi khi cập nhật vai trò'),
                        backgroundColor: AppColors.badgeRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Lưu vai trò', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'owner':
        return const Color(0xFFB45309); // Cam đậm/Vàng đồng
      case 'editor':
        return const Color(0xFF1D4ED8); // Xanh dương
      default:
        return const Color(0xFF4B5563); // Xám
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
        title: const Text(
          'Phân quyền thành viên',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _users.isEmpty
              ? const Center(
                  child: Text(
                    'Không có tài khoản người dùng nào trong gia phả',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: _users.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final firstChar = user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : (user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U');

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF0E5DC)),
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
                            // Avatar
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFF3E7DC),
                              child: Text(
                                firstChar,
                                style: const TextStyle(
                                  color: Color(0xFF5A2E10),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // User info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (user.isOwner) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Chủ gia phả',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getRoleBadgeColor(user.role).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          user.roleDisplay,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: _getRoleBadgeColor(user.role),
                                          ),
                                        ),
                                      ),
                                      if (user.generationInfo.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${user.generationInfo}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Nút Đổi quyền
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDF7F2),
                                foregroundColor: const Color(0xFF5A2E10),
                                elevation: 0,
                                side: const BorderSide(color: Color(0xFFE8DFD8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showChangeRoleDialog(user),
                              child: const Text(
                                'Đổi quyền',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
