import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_color.dart';
import '../models/member_model.dart';
import 'add_member_screen.dart';
import '../repositories/member_repository.dart';


/// Màn hình Hồ Sơ Thành Viên.
/// Thiết kế theo Figma: AppBar nâu, avatar lớn, 4 stat card,
/// section thông tin cá nhân (bao gồm CCCD), thông tin gia đình.
class MemberProfileScreen extends StatefulWidget {
  final MemberModel member;
  final List<MemberModel> allMembers;
  final bool canManage;
  final ValueChanged<MemberModel>? onUpdated;
  final ValueChanged<MemberModel>? onMemberAdded;

  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.allMembers,
    this.canManage = false,
    this.onUpdated,
    this.onMemberAdded,
  });

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late MemberModel _member;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
  }

  MemberModel? _findById(String? id) {
    if (id == null) return null;
    try {
      return widget.allMembers.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  List<MemberModel> get _children {
    return widget.allMembers
        .where((m) => m.fatherId == _member.id || m.motherId == _member.id)
        .toList();
  }

  MemberModel? get _spouse {
    for (final child in _children) {
      if (_member.gender == 'Nam' && child.motherId != null) {
        try {
          return widget.allMembers.firstWhere((m) => m.id == child.motherId);
        } catch (_) {}
      } else if (_member.gender == 'Nữ' && child.fatherId != null) {
        try {
          return widget.allMembers.firstWhere((m) => m.id == child.fatherId);
        } catch (_) {}
      }
    }
    return null;
  }

  bool get _isAlive => _member.status == 'Còn sống';

  void _goToProfile(MemberModel m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberProfileScreen(
          member: m,
          allMembers: widget.allMembers,
          onUpdated: widget.onUpdated,
          onMemberAdded: widget.onMemberAdded,
        ),
      ),
    );
  }

  void _onEdit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMemberScreen(
          existingMembers: widget.allMembers,
          initialMember: _member,
          onSaved: (updated) async {
            if (_member.id == null) return;
            try {
              final result = await MemberRepository.updateMember(
                _member.id!,
                updated,
              );
              if (mounted) {
                setState(() => _member = result);
                widget.onUpdated?.call(result);
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
                    content: Text('Lỗi khi lưu vào cơ sở dữ liệu: $e'),
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

  void _onAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMemberScreen(
          existingMembers: widget.allMembers,
          onSaved: (newMember) async {
            try {
              final created = await MemberRepository.addMember(newMember);
              if (mounted) {
                widget.onMemberAdded?.call(created);
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
                    content: Text('Lỗi khi thêm thành viên: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatarHeader(),
                  const SizedBox(height: 20),
                  _buildStatRow(),
                  const SizedBox(height: 16),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 16),
                  _buildFamilyInfoSection(),
                  if (_member.notes != null && _member.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildNotesSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          const Expanded(
            child: Text(
              'Hồ sơ thành viên',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (widget.canManage) ...[
            GestureDetector(
              onTap: _onEdit,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Chỉnh sửa',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _onAdd,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Thêm',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarHeader() {
    final bool isMale = _member.gender == 'Nam';

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMale ? AppColors.maleBg : AppColors.femaleBg,
            border: Border.all(
              color: isMale ? AppColors.male : AppColors.female,
              width: 2.5,
            ),
          ),
          child: ClipOval(
            child: _member.resolvedAvatarUrl != null && _member.resolvedAvatarUrl!.isNotEmpty
                ? Image.network(
                    _member.resolvedAvatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _buildDefaultAvatar(isMale),
                  )
                : _buildDefaultAvatar(isMale),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _member.fullName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _member.generation != null
                  ? 'Đời thứ ${_member.generation}'
                  : 'Chưa xác định đời',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(bool isMale) {
    return Icon(
      Icons.person_outline_rounded,
      size: 42,
      color: isMale ? AppColors.male : AppColors.female,
    );
  }

  Widget _buildStatRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
          Expanded(
            child: _buildStatItem(
              icon: Icons.calendar_today_outlined,
              value: _member.dateOfBirth ?? '—',
              label: 'Ngày sinh',
            ),
          ),
          _buildVertDivider(),
          Expanded(
            child: _buildStatItem(
              icon: _member.gender == 'Nam'
                  ? Icons.male_rounded
                  : Icons.female_rounded,
              value: _member.gender,
              label: 'Giới tính',
              iconColor: _member.gender == 'Nam'
                  ? AppColors.male
                  : AppColors.female,
            ),
          ),
          _buildVertDivider(),
          Expanded(
            child: _buildStatItem(
              icon: Icons.water_drop_outlined,
              value: _member.status,
              label: 'Tình trạng',
              iconColor: _isAlive ? AppColors.success : AppColors.textMuted,
            ),
          ),
          _buildVertDivider(),
          Expanded(
            child: _buildStatItem(
              icon: Icons.location_on_outlined,
              value: _member.placeOfBirth ?? '—',
              label: 'Nơi sinh',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVertDivider() {
    return Container(
      width: 1,
      height: 48,
      color: AppColors.divider,
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: iconColor ?? AppColors.primaryMedium,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Thông tin cá nhân',
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Số điện thoại',
            value: _member.phoneNumber ?? '—',
            copyable: true,
          ),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Địa chỉ',
            value: _member.currentAddress ?? '—',
          ),
          _buildInfoRow(
            icon: Icons.credit_card_rounded,
            label: 'CCCD',
            value: _member.identityCard ?? '—',
            copyable: true,
          ),
          _buildInfoRow(
            icon: Icons.work_outline_rounded,
            label: 'Nghề nghiệp',
            value: _member.occupation ?? '—',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyInfoSection() {
    final father = _findById(_member.fatherId);
    final mother = _findById(_member.motherId);
    final spouse = _spouse;
    final children = _children;

    return _buildSectionCard(
      icon: Icons.cottage_outlined,
      title: 'Thông tin gia đình',
      child: Column(
        children: [
          _buildFamilyRow(
            icon: Icons.person_outline_rounded,
            label: 'Bố',
            value: father?.fullName ?? _member.fatherName ?? '—',
            member: father,
            isLast: false,
          ),
          _buildFamilyRow(
            icon: Icons.person_outline_rounded,
            label: 'Mẹ',
            value: mother?.fullName ?? _member.motherName ?? '—',
            member: mother,
            isLast: false,
          ),
          _buildFamilyRow(
            icon: Icons.favorite_outline_rounded,
            label: 'Vợ/chồng',
            value: spouse?.fullName ?? '—',
            member: spouse,
            isLast: false,
          ),
          _buildFamilyRow(
            icon: Icons.people_outline_rounded,
            label: 'Con',
            value: children.isEmpty ? '—' : '${children.length} người',
            member: null,
            childList: children.isEmpty ? null : children,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _buildSectionCard(
      icon: Icons.edit_note_rounded,
      title: 'Ghi chú',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          _member.notes!,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryMedium),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onLongPress: copyable && value != '—'
                      ? () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã sao chép: $value'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }

  Widget _buildFamilyRow({
    required IconData icon,
    required String label,
    required String value,
    required MemberModel? member,
    List<MemberModel>? childList,
    bool isLast = false,
  }) {
    final bool tappable = member != null || (childList != null && childList.isNotEmpty);

    return Column(
      children: [
        InkWell(
          onTap: tappable
              ? () {
                  if (member != null) {
                    _goToProfile(member);
                  } else if (childList != null && childList.isNotEmpty) {
                    _showChildrenSheet(childList);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: tappable ? AppColors.primaryMedium : AppColors.textPrimary,
                  ),
                ),
                if (tappable) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }

  void _showChildrenSheet(List<MemberModel> children) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    size: 18,
                    color: AppColors.primaryMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Danh sách con (${children.length} người)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider),
            ...children.map(
              (child) => ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: child.gender == 'Nam' ? AppColors.maleBg : AppColors.femaleBg,
                    border: Border.all(
                      color: child.gender == 'Nam' ? AppColors.male : AppColors.female,
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: child.gender == 'Nam' ? AppColors.male : AppColors.female,
                  ),
                ),
                title: Text(
                  child.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  child.gender,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _goToProfile(child);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
