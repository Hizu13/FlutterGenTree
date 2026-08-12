import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/member_model.dart';
import '../widgets/member_card.dart';
import '../widgets/member_filter_bar.dart';
import '../widgets/member_summary_card.dart';
import 'add_member_screen.dart';
import 'member_profile_screen.dart';
import '../repositories/member_repository.dart';




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

 // ── Dữ liệu toàn cục từ Repository ──────────────────────────────────────────
  final List<MemberModel> _allMembers = MemberRepository.members;
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
        body: Column(
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
              onGenerationChanged: (val) => setState(() => _selectedGeneration = val),
              onGenderChanged: (val) => setState(() => _selectedGender = val),
              onAddressChanged: (val) => setState(() => _selectedAddress = val),
              onSortTap: _showSortBottomSheet,
            ),

            // ── Danh sách thành viên ─────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final member = filtered[index];
                        return MemberCard(
                          member: member,
                          onTap: () => _onMemberTap(member),
                          onMoreTap: () => _showMemberOptions(member),
                        );
                      },
                    ),
            ),

            // ── Thống kê Footer ───────────────────────────────────────────────
            MemberSummaryCard(
              totalCount: _allMembers.length,
              maleCount: _maleCount,
              femaleCount: _femaleCount,
            ),
          ],
        ),

        // ── FAB Thêm mới ──────────────────────────────────────────────────────
        floatingActionButton: FloatingActionButton(
          onPressed: _onAddMember,
          backgroundColor: AppColors.primaryGold,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
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
            onTap: () => Navigator.of(context).maybePop(),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thành viên',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Quản lý thành viên trong gia phả',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Nút Thêm mới
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
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
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
          onSaved: (newMember) {
            setState(() {
              _allMembers.add(newMember);
            });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
                content: Text('Đã thêm thành viên: ${newMember.fullName}'),
                backgroundColor: AppColors.primaryMedium,
        behavior: SnackBarBehavior.floating,
   shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),      ),
    );
  }

  void _showMemberOptions(MemberModel member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
builder: (_) => _MemberOptionsSheet(
        member: member,
        onViewProfile: () {
          Navigator.pop(context);
          _onMemberTap(member);
        },
        onEdit: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddMemberScreen(
                existingMembers: _allMembers,
                initialMember: member,
                onSaved: (updated) {
                  setState(() {
                    final idx = _allMembers.indexWhere((m) => m.id == updated.id);
                    if (idx != -1) {
                      _allMembers[idx] = updated;
                    }
                  });
                },
              ),
            ),
          );
        },
        onDelete: () {
          Navigator.pop(context);
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
        },
      ),    );
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
// BOTTOM SHEET: Tùy chọn thành viên (Xem / Sửa / Xóa)
// =============================================================================
class _MemberOptionsSheet extends StatelessWidget {
  final MemberModel member;
  final VoidCallback? onViewProfile;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MemberOptionsSheet({
    required this.member,
    this.onViewProfile,
    this.onEdit,
    this.onDelete,
  });
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

          // Tên thành viên
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              member.fullName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: AppColors.divider),

          _buildOption(
            context,
            icon: Icons.person_outline_rounded,
            label: 'Xem hồ sơ',
            color: AppColors.textPrimary,
            onTap: onViewProfile,
          ),
          _buildOption(
            context,
            icon: Icons.edit_outlined,
            label: 'Chỉnh sửa thông tin',
            color: AppColors.primaryMedium,
            onTap: onEdit,
          ),
          _buildOption(
            context,
            icon: Icons.account_tree_outlined,
            label: 'Xem trong sơ đồ gia phả',
            color: AppColors.primaryGold,
            onTap: () => Navigator.pop(context),
          ),
          const Divider(color: AppColors.divider, height: 1),
_buildOption(
            context,
            icon: Icons.delete_outline_rounded,
            label: 'Xóa thành viên',
            color: AppColors.error,
            onTap: onDelete,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

 Widget _buildOption(
    BuildContext context, {    required IconData icon,
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
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color == AppColors.error ? color : AppColors.textPrimary,
                fontWeight: color == AppColors.error ? FontWeight.w500 : FontWeight.w400,
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
