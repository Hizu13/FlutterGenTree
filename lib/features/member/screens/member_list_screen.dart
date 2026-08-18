import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/member_model.dart';
import '../widgets/member_card.dart';
import '../widgets/member_filter_bar.dart';
import '../widgets/member_summary_card.dart';
import 'add_member_screen.dart';
import 'member_profile_screen.dart';
import '../repositories/member_repository.dart';
import '../../family/models/family_model.dart';
import '../../family/services/family_api_service.dart';
import '../../auth/models/auth_request_model.dart';
import '../../auth/services/auth_service.dart';

/// Màn hình Danh Sách Thành Viên.
/// Thiết kế theo Figma: AppBar nâu đậm, ô tìm kiếm, bộ lọc Đời/Giới tính/Địa chỉ,
/// danh sách thẻ thành viên, footer thống kê, FAB "+".
class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String? _selectedGeneration;
  String? _selectedGender;
  String? _selectedAddress;

// ── Dữ liệu từ Backend API ──────────────────────────────────────────────
  List<MemberModel> _allMembers = [];
  FamilyModel? _currentFamily;
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  /// Quyền hạn của người dùng hiện tại trong gia phả này
  bool get _isAdmin {
    final famRole = _currentFamily?.userRole;
    final userRole = _currentUser?.role;
    final String role = (famRole ?? userRole ?? 'member').toLowerCase();
    if (role == 'admin' || role == 'owner') return true;
    if (_currentFamily?.ownerId != null && _currentUser?.id != null && _currentFamily!.ownerId == _currentUser!.id) {
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

  /// Kiểm tra xem thành viên này có phải là bản thân tài khoản đang đăng nhập không
  bool _checkIsSelf(MemberModel member) {
    if (_currentUser == null) return false;
    // 1. Khớp qua user_id
    if (member.userId != null && _currentUser!.id != null && member.userId == _currentUser!.id) {
      return true;
    }
    // 2. Khớp qua CCCD / CMND
    if (member.identityCard != null && _currentUser!.cccd != null) {
      final mCccd = member.identityCard!.trim();
      final uCccd = _currentUser!.cccd!.trim();
      if (mCccd.isNotEmpty && uCccd.isNotEmpty && mCccd == uCccd) {
        return true;
      }
    }
    // 3. Khớp qua Số điện thoại / Username
    if (member.phoneNumber != null && _currentUser!.username.isNotEmpty) {
      final mPhone = member.phoneNumber!.replaceAll(RegExp(r'\D'), '');
      final uName = _currentUser!.username.replaceAll(RegExp(r'\D'), '');
      if (mPhone.isNotEmpty && uName.isNotEmpty && mPhone == uName) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final family = await FamilyApiService.getCurrentFamily();
      final user = await AuthService.getSavedUser();
      final data = await MemberRepository.fetchAll(
        forceRefresh: true,
        familyId: family?.id,
      );
      if (mounted) {
        setState(() {
          _currentFamily = family;
          _currentUser = user;
          _allMembers = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<MemberModel> get _filteredMembers {
    return _allMembers.where((m) {
      // Lọc theo tìm kiếm
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = m.fullName.toLowerCase().contains(q);
        final phoneMatch = m.phoneNumber?.toLowerCase().contains(q) ?? false;
        if (!nameMatch && !phoneMatch) return false;
      }
      // Lọc theo đời
      if (_selectedGeneration != null) {
        final gen = int.tryParse(_selectedGeneration!.replaceAll('Đời ', ''));
        if (m.generation != gen) return false;
      }
      // Lọc theo giới tính
      if (_selectedGender != null && m.gender != _selectedGender) return false;
      // Lọc theo địa chỉ
      if (_selectedAddress != null) {
        final addr = (m.currentAddress ?? m.placeOfBirth ?? '').toLowerCase();
        if (!addr.contains(_selectedAddress!.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  List<String> get _generationOptions {
    final gens = _allMembers
        .where((m) => m.generation != null)
        .map((m) => m.generation!)
        .toSet()
        .toList()
      ..sort();
    return gens.map((g) => 'Đời $g').toList();
  }

  List<String> get _addressOptions {
    final addrs = _allMembers
        .map((m) => m.currentAddress ?? m.placeOfBirth ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return addrs;
  }

  int get _maleCount => _allMembers.where((m) => m.gender == 'Nam').length;
  int get _femaleCount => _allMembers.where((m) => m.gender == 'Nữ').length;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMembers;

    return GestureDetector(
      // Đóng dropdown khi bấm ngoài
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
         body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // ── AppBar tuỳ chỉnh ─────────────────────────────────────────────
                  _buildAppBar(context),

                  // ── Ô tìm kiếm ──────────────────────────────────────────────────
                  _buildSearchBar(),

                  // ── Thanh bộ lọc ─────────────────────────────────────────────────
                  MemberFilterBar(
                    totalCount: _allMembers.length,
                    selectedGeneration: _selectedGeneration,
                    selectedGender: _selectedGender,
                    selectedAddress: _selectedAddress,
                    generationOptions: _generationOptions,
                    addressOptions: _addressOptions,
                    onGenerationChanged: (val) =>
                        setState(() => _selectedGeneration = val),
                    onGenderChanged: (val) =>
                        setState(() => _selectedGender = val),
                    onAddressChanged: (val) =>
                        setState(() => _selectedAddress = val),
                    onSortTap: _showSortBottomSheet,
                  ),

                  // ── Danh sách thành viên ─────────────────────────────────────────
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryMedium,
                            ),
                          )
                        : _errorMessage != null
                        ? _buildErrorState()
                        : filtered.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadMembers,
                            color: AppColors.primaryMedium,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 6, bottom: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final member = filtered[index];
                                final bool isSelf = _checkIsSelf(member);
                                return MemberCard(
                                  member: member,
                                  canManage: _canManage,
                                  isSelf: isSelf,
                                  onTap: () => _onMemberTap(member),
                                  onMoreTap: () => _showMemberOptions(member),
                                );
                              },
                            ),
                          ),
                  ),

                  // place a spacer at bottom so list not hidden by floating card
                  const SizedBox(height: 120),
                ],
              ),

              // Floating summary card at bottom-left (small pill)
              Positioned(
                left: 16,
                bottom: 16,
                child: SizedBox(
                  width: 300,
                  child: MemberSummaryCard(
                    totalCount: _allMembers.length,
                    maleCount: _maleCount,
                    femaleCount: _femaleCount,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── FAB Thêm mới (Chỉ hiển thị cho Admin và Editor) ────────────────────
        floatingActionButton: _canManage
            ? FloatingActionButton(
                onPressed: _onAddMember,
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.add_rounded, size: 28),
              )
            : null,
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================
  Widget _buildAppBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 16,
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
          // Nút Back
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Tiêu đề
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thành viên',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _currentFamily != null
                      ? 'Gia phả: ${_currentFamily!.name}'
                      : 'Quản lý thành viên trong gia phả',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Nút Thêm mới (Chỉ hiển thị cho Admin và Editor)
          if (_canManage)
            GestureDetector(
              onTap: _onAddMember,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                  Text(
                    'Thêm mới',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Nút Bộ lọc
          GestureDetector(
            onTap: _showFilterBottomSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: const Row(
                children: [
                  Icon(Icons.filter_list_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Bộ lọc',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH BAR
  // ===========================================================================
  Widget _buildSearchBar() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm thành viên...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: AppColors.primaryMedium,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy thành viên',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không thể kết nối Backend',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadMembers,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMedium,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ACTIONS
  // ===========================================================================
  void _onMemberTap(MemberModel member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberProfileScreen(
          member: member,
          allMembers: _allMembers,
          canManage: _canManage,
          onUpdated: (updated) {
            setState(() {
              final idx = _allMembers.indexWhere((m) => m.id == updated.id);
              if (idx != -1) {
                _allMembers[idx] = updated;
              }
            });
          },
          onMemberAdded: (newMember) {
            setState(() {
              _allMembers.add(newMember);
            });
          },
        ),
      ),
    );
  }

  void _onAddMember() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMemberScreen(
          existingMembers: _allMembers,
          onSaved: (newMember) async {
            try {
              final created = await MemberRepository.addMember(newMember);
              if (mounted) {
                setState(() {
                  final idx = _allMembers.indexWhere((m) => m.id == created.id);
                  if (idx == -1) {
                    _allMembers.add(created);
                  } else {
                    _allMembers[idx] = created;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã thêm thành viên: ${created.fullName}'),
                    backgroundColor: AppColors.primaryMedium,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi: $e'),
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
        ),
      ),
    );
  }

  void _showMemberOptions(MemberModel member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _MemberOptionsSheet(
        member: member,
        isAdmin: _isAdmin,
        isEditor: _isEditor,
        onViewProfile: () {
          Navigator.pop(sheetCtx);
          _onMemberTap(member);
        },
        onEdit: () {
          Navigator.pop(sheetCtx);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddMemberScreen(
                existingMembers: _allMembers,
                initialMember: member,
                onSaved: (updated) async {
                  try {
                    final result = await MemberRepository.updateMember(
                      member.id!,
                      updated,
                    );
                    if (mounted) {
                      setState(() {
                        final idx = _allMembers.indexWhere(
                          (m) => m.id == member.id,
                        );
                        if (idx != -1) {
                          _allMembers[idx] = result;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã cập nhật: ${result.fullName}'),
                          backgroundColor: AppColors.primaryMedium,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
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
              ),
            ),
          );
        },
        onToggleRole: () async {
          Navigator.pop(sheetCtx);
          final bool isCurrentlyEditor = member.role == 'editor';
          final String newRole = isCurrentlyEditor ? 'member' : 'editor';
          final String actionText = isCurrentlyEditor ? 'hủy quyền Editor' : 'cấp quyền Editor';

          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isCurrentlyEditor ? Icons.remove_moderator_rounded : Icons.admin_panel_settings_rounded,
                    color: isCurrentlyEditor ? AppColors.badgeRed : AppColors.editorRoleText,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCurrentlyEditor ? 'Hủy quyền Editor' : 'Phân quyền Editor',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(
                'Bạn có chắc chắn muốn $actionText cho thành viên "${member.fullName}" không?',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentlyEditor ? AppColors.badgeRed : AppColors.editorRoleText,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isCurrentlyEditor ? 'Hủy quyền' : 'Cấp quyền'),
                ),
              ],
            ),
          );

          if (confirm == true && mounted) {
            try {
              await MemberRepository.updateRole(member.id!, newRole);
              if (mounted) {
                setState(() {
                  final idx = _allMembers.indexWhere((m) => m.id == member.id);
                  if (idx != -1) {
                    _allMembers[idx] = member.copyWith(role: newRole);
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã $actionText cho ${member.fullName} thành công'),
                    backgroundColor: isCurrentlyEditor ? AppColors.primaryDark : AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi phân quyền: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            }
          }
        },
        onDelete: () async {
          Navigator.pop(sheetCtx);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 24),
                  SizedBox(width: 8),
                  Text('Xác nhận xóa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Bạn có chắc chắn muốn xóa thành viên "${member.fullName}" khỏi gia phả? Hành động này không thể hoàn tác.',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Xóa vĩnh viễn'),
                ),
              ],
            ),
          );

          if (confirm == true && mounted) {
            try {
              await MemberRepository.deleteMember(member.id!);
              if (mounted) {
                setState(() {
                  _allMembers.removeWhere((m) => m.id == member.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa thành viên: ${member.fullName}'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi xóa: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(
        onSelected: (sort) {
          Navigator.pop(context);
          // TODO: apply sort
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    // TODO: Advanced filter bottom sheet
  }
}

// =============================================================================
// BOTTOM SHEET: Tùy chọn thành viên (Phân quyền / Xem / Sửa / Xóa)
// =============================================================================
class _MemberOptionsSheet extends StatelessWidget {
  final MemberModel member;
  final bool isAdmin;
  final bool isEditor;
  final VoidCallback? onViewProfile;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleRole;
  final VoidCallback? onDelete;

  const _MemberOptionsSheet({
    required this.member,
    this.isAdmin = false,
    this.isEditor = false,
    this.onViewProfile,
    this.onEdit,
    this.onToggleRole,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMemberAdmin = member.role == 'admin' || member.role == 'owner';
    final bool isMemberEditor = member.role == 'editor';

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Tên thành viên + Role tag
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    member.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMemberAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.adminRoleBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.adminRoleText)),
                  ),
                ] else if (isMemberEditor) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.editorRoleBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Editor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.editorRoleText)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: AppColors.divider),

          // 1. Xem hồ sơ
          _buildOption(
            context,
            icon: Icons.person_outline_rounded,
            label: 'Xem hồ sơ',
            color: AppColors.textPrimary,
            onTap: onViewProfile,
          ),

          // 2. Chỉnh sửa thông tin (Admin & Editor)
          if (isAdmin || isEditor)
            _buildOption(
              context,
              icon: Icons.edit_outlined,
              label: 'Chỉnh sửa thông tin',
              color: AppColors.primaryMedium,
              onTap: onEdit,
            ),

          // 3. Phân quyền / Hủy quyền Editor (Chỉ Admin mới có quyền)
          if (isAdmin && !isMemberAdmin) ...[
            if (isMemberEditor)
              _buildOption(
                context,
                icon: Icons.remove_moderator_outlined,
                label: 'Hủy quyền Editor (Về thành viên thường)',
                color: AppColors.primaryMedium,
                onTap: onToggleRole,
              )
            else
              _buildOption(
                context,
                icon: Icons.admin_panel_settings_outlined,
                label: 'Phân quyền Editor (Cấp quyền chỉnh sửa)',
                color: AppColors.editorRoleText,
                onTap: onToggleRole,
              ),
          ],

          // 4. Xem trong sơ đồ gia phả
          _buildOption(
            context,
            icon: Icons.account_tree_outlined,
            label: 'Xem trong sơ đồ gia phả',
            color: AppColors.primaryGold,
            onTap: () => Navigator.pop(context),
          ),

          // 5. Xóa thành viên (Admin & Editor)
          if (isAdmin || isEditor) ...[
            const Divider(color: AppColors.divider, height: 1),
            _buildOption(
              context,
              icon: Icons.delete_outline_rounded,
              label: 'Xóa thành viên khỏi gia phả',
              color: AppColors.error,
              onTap: onDelete,
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color == AppColors.error ? color : AppColors.textPrimary,
                  fontWeight: color == AppColors.error ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BOTTOM SHEET: Sắp xếp
// =============================================================================
class _SortSheet extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _SortSheet({required this.onSelected});

  static const _options = [
    ('Tên (A → Z)', Icons.sort_by_alpha_rounded),
    ('Tên (Z → A)', Icons.sort_by_alpha_rounded),
    ('Đời (Nhỏ → Lớn)', Icons.trending_up_rounded),
    ('Đời (Lớn → Nhỏ)', Icons.trending_down_rounded),
    ('Năm sinh (Cũ → Mới)', Icons.calendar_today_outlined),
    ('Năm sinh (Mới → Cũ)', Icons.calendar_today_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sắp xếp theo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.divider),
          ..._options.map(
            (opt) => InkWell(
              onTap: () => onSelected(opt.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                child: Row(
                  children: [
                    Icon(opt.$2, size: 18, color: AppColors.primaryMedium),
                    const SizedBox(width: 14),
                    Text(
                      opt.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
