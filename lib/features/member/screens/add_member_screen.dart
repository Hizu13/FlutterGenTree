import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/member_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/member_api_service.dart';


class AddMemberScreen extends StatefulWidget {
  /// Danh sách thành viên hiện có (để chọn bố/mẹ)
  final List<MemberModel> existingMembers;

  /// Callback khi lưu thành công, trả về MemberModel vừa tạo/cập nhật
  final ValueChanged<MemberModel> onSaved;

  /// Thành viên cần chỉnh sửa (nếu có)
  final MemberModel? initialMember;
  const AddMemberScreen({
    super.key,
    required this.existingMembers,
    required this.onSaved,
    this.initialMember,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _pobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dodCtrl = TextEditingController();
  final _placeOfDeathCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _identityCardCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  String _gender = 'Nam';
  String _status = 'Còn sống';
  MemberModel? _selectedFather;
  MemberModel? _selectedMother;
  XFile? _avatarFile;
  String? _avatarUrl;
  @override
  void initState() {
    super.initState();
    final init = widget.initialMember;
    if (init != null) {
      _nameCtrl.text = init.fullName;
      _dobCtrl.text = init.dateOfBirth ?? '';
      _pobCtrl.text = init.placeOfBirth ?? '';
      _phoneCtrl.text = init.phoneNumber ?? '';
      _emailCtrl.text = init.email ?? '';
      _addressCtrl.text = init.currentAddress ?? '';
      _dodCtrl.text = init.dateOfDeath ?? '';
      _placeOfDeathCtrl.text = init.placeOfDeath ?? '';
      _occupationCtrl.text = init.occupation ?? '';
      _notesCtrl.text = init.notes ?? '';
      _identityCardCtrl.text = init.identityCard ?? '';
      _gender = init.gender;
      _status = init.status;
      _avatarUrl = init.avatarUrl;
      if (init.fatherId != null) {
        try {
          _selectedFather = widget.existingMembers.firstWhere(
            (m) => m.id == init.fatherId,
          );
        } catch (_) {}
      }
      if (init.motherId != null) {
        try {
          _selectedMother = widget.existingMembers.firstWhere(
            (m) => m.id == init.motherId,
          );
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _pobCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _dodCtrl.dispose();
    _placeOfDeathCtrl.dispose();
    _occupationCtrl.dispose();
    _notesCtrl.dispose();
    _identityCardCtrl.dispose();
    super.dispose();
  }

  // ── Các thành viên Nam (có thể làm bố) ─────────────────────────────────
  List<MemberModel> get _maleMembers =>
      widget.existingMembers.where((m) => m.gender == 'Nam').toList();

  // ── Các thành viên Nữ (có thể làm mẹ) ─────────────────────────────────
  List<MemberModel> get _femaleMembers =>
      widget.existingMembers.where((m) => m.gender == 'Nữ').toList();

  // ── Lưu thành viên ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id =
        widget.initialMember?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final member = MemberModel(
      id: id,
      fullName: _nameCtrl.text.trim(),
      gender: _gender,
      status: _status,
      dateOfBirth: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
      placeOfBirth: _pobCtrl.text.trim().isEmpty ? null : _pobCtrl.text.trim(),
      fatherId: _selectedFather?.id,
      fatherName: _selectedFather?.fullName,
      motherId: _selectedMother?.id,
      motherName: _selectedMother?.fullName,
      phoneNumber: _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      currentAddress: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      dateOfDeath: _dodCtrl.text.trim().isEmpty ? null : _dodCtrl.text.trim(),
      placeOfDeath: _placeOfDeathCtrl.text.trim().isEmpty
          ? null
          : _placeOfDeathCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim().isEmpty
          ? null
          : _occupationCtrl.text.trim(),
      identityCard: _identityCardCtrl.text.trim().isEmpty
          ? null
          : _identityCardCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      generation: widget.initialMember?.generation,
      avatarUrl: widget.initialMember?.avatarUrl,
    );

    String? finalAvatarUrl = _avatarUrl ?? widget.initialMember?.avatarUrl;

    if (_avatarFile != null) {
      if (!mounted) return;
      // show simple loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final uploaded = await MemberApiService.uploadImage(
          File(_avatarFile!.path),
        );
        finalAvatarUrl = uploaded;
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể upload ảnh: $e')));
        return;
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    }

    final memberWithAvatar = member.copyWith(avatarUrl: finalAvatarUrl);
    widget.onSaved(memberWithAvatar);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.length();
      const maxBytes = 5 * 1024 * 1024; // 5MB
      if (bytes > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ảnh quá lớn (>5MB). Vui lòng chọn ảnh khác.'),
            ),
          );
        }
        return;
      }

      setState(() {
        _avatarFile = picked;
        _avatarUrl = null; // clear remote url when new file chosen
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  // ── Huỷ ─────────────────────────────────────────────────────────────────
  void _cancel() => Navigator.of(context).pop();

  // ── Chọn ngày ────────────────────────────────────────────────────────────
  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1800),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      ctrl.text = '$day/$month/$year';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── AppBar ──────────────────────────────────────────────────────
          _buildAppBar(context),

          // ── Form cuộn ───────────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  // Section 1: Thông tin cá nhân
                  _buildSectionCard(
                    icon: Icons.person_outline_rounded,
                    title: '1. Thông tin cá nhân',
                    child: _buildPersonalInfoSection(),
                  ),

                  const SizedBox(height: 12),

                  // Section 2: Thông tin gia đình
                  _buildSectionCard(
                    icon: Icons.people_outline_rounded,
                    title: '2. Thông tin gia đình',
                    child: _buildFamilyInfoSection(),
                  ),

                  const SizedBox(height: 12),

                  // Section 3: Thông tin liên hệ
                  _buildSectionCard(
                    icon: Icons.phone_outlined,
                    title: '3. Thông tin liên hệ',
                    child: _buildContactInfoSection(),
                  ),

                  const SizedBox(height: 12),

                  // Section 4: Thông tin bổ sung
                  _buildSectionCard(
                    icon: Icons.article_outlined,
                    title: 'Thông tin bổ sung',
                    child: _buildAdditionalInfoSection(),
                  ),

                  const SizedBox(height: 24),

                  // ── Nút Hủy / Lưu ─────────────────────────────────────
                  _buildActionButtons(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
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
            onTap: _cancel,
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
                Text(
                  widget.initialMember != null
                      ? 'Chỉnh sửa thành viên'
                      : 'Thêm thành viên',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.initialMember != null
                      ? 'Cập nhật thông tin thành viên'
                      : 'Nhập thông tin thành viên mới',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Nút Lưu
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white54),
              ),
              child: const Text(
                'Lưu',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION CARD WRAPPER
  // ===========================================================================
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primaryMedium),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: THÔNG TIN CÁ NHÂN
  // ===========================================================================
  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ảnh đại diện căn giữa phía trên ──────────────────────────
        Center(
          child: _buildAvatarPicker(),
        ),
        const SizedBox(height: 16),

        // Họ và tên
        _buildLabel('Họ và tên *'),
        _buildTextFormField(
          controller: _nameCtrl,
          hint: 'Nhập họ và tên',
          prefixIcon: Icons.person_outline_rounded,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Vui lòng nhập họ và tên'
              : null,
        ),

        const SizedBox(height: 12),

        // Giới tính + Trạng thái
        Row(
          children: [
            // Giới tính
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Giới tính'),
                  _buildGenderSelector(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Trạng thái
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Trạng thái'),
                  _buildStatusDropdown(),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Ngày sinh + Nơi sinh
        Row(
          children: [
            // Ngày sinh
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Ngày sinh'),
                  _buildDateField(
                    controller: _dobCtrl,
                    hint: 'dd/mm/yyyy',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Nơi sinh
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Nơi sinh'),
                  _buildTextFormField(
                    controller: _pobCtrl,
                    hint: 'Nhập nơi sinh',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Căn cước công dân
        _buildLabel('Căn cước công dân'),
        _buildTextFormField(
          controller: _identityCardCtrl,
          hint: 'Nhập số căn cước công dân',
          prefixIcon: Icons.badge_outlined,
        ),
      ],
    );
  }

  // ── Avatar picker ──────────────────────────────────────────────────────
  Widget _buildAvatarPicker() {
    Widget avatarChild;
    if (_avatarFile != null) {
      avatarChild = ClipOval(
        child: Image.file(
          File(_avatarFile!.path),
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      );
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          _avatarUrl!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      );
    } else {
      avatarChild = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 26,
            color: AppColors.primaryMedium,
          ),
          SizedBox(height: 4),
          Text(
            'Thêm ảnh',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primaryMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: avatarChild,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Định dạng: jpeg, png (Tối đa 5MB)',
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // ── Gender Selector ────────────────────────────────────────────────────
  Widget _buildGenderSelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Nam
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _gender = 'Nam'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _gender == 'Nam'
                      ? AppColors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _gender == 'Nam'
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.male_rounded,
                      size: 16,
                      color: _gender == 'Nam'
                          ? AppColors.male
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Nam',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _gender == 'Nam'
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Nữ
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _gender = 'Nữ'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _gender == 'Nữ' ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _gender == 'Nữ'
                      ? [
                          BoxShadow(
                            color: AppColors.female.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.female_rounded,
                      size: 16,
                      color: _gender == 'Nữ'
                          ? AppColors.female
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Nữ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _gender == 'Nữ'
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Dropdown ────────────────────────────────────────────────────
  Widget _buildStatusDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _status,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          dropdownColor: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          items: const [
            DropdownMenuItem(
              value: 'Còn sống',
              child: Text(
                'Còn sống',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'Đã mất',
              child: Text(
                'Đã mất',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _status = val);
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: THÔNG TIN GIA ĐÌNH
  // ===========================================================================
  Widget _buildFamilyInfoSection() {
    return Row(
      children: [
        // Quan hệ với bố
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Quan hệ với bố'),
              _buildMemberDropdown(
                hint: 'Chọn tên bố',
                members: _maleMembers,
                selected: _selectedFather,
                onChanged: (m) => setState(() => _selectedFather = m),
                icon: Icons.person_outline_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Quan hệ với mẹ
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Quan hệ với mẹ'),
              _buildMemberDropdown(
                hint: 'Chọn tên mẹ',
                members: _femaleMembers,
                selected: _selectedMother,
                onChanged: (m) => setState(() => _selectedMother = m),
                icon: Icons.person_outline_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Member dropdown ────────────────────────────────────────────────────
  Widget _buildMemberDropdown({
    required String hint,
    required List<MemberModel> members,
    required MemberModel? selected,
    required ValueChanged<MemberModel?> onChanged,
    required IconData icon,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MemberModel>(
          value: selected,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          dropdownColor: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          items: [
            const DropdownMenuItem<MemberModel>(
              value: null,
              child: Text(
                '— Không chọn —',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            ...members.map(
              (m) => DropdownMenuItem<MemberModel>(
                value: m,
                child: Text(
                  m.fullName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: THÔNG TIN LIÊN HỆ
  // ===========================================================================
  Widget _buildContactInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Số điện thoại + Email
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Số điện thoại'),
                  _buildTextFormField(
                    controller: _phoneCtrl,
                    hint: 'Nhập số điện thoại',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Email (nếu có)'),
                  _buildTextFormField(
                    controller: _emailCtrl,
                    hint: 'Nhập email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Địa chỉ hiện tại
        _buildLabel('Địa chỉ hiện tại'),
        _buildTextFormField(
          controller: _addressCtrl,
          hint: 'Nhập địa chỉ hiện tại',
          prefixIcon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 4: THÔNG TIN BỔ SUNG (ngày mất, nơi mất, nghề nghiệp, ghi chú)
  // ===========================================================================
  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ngày mất + Nơi mất
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Ngày mất (nếu có)'),
                  _buildDateField(controller: _dodCtrl, hint: 'dd/mm/yyyy'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Nơi mất (nếu có)'),
                  _buildTextFormField(
                    controller: _placeOfDeathCtrl,
                    hint: 'Nhập nơi mất',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Nghề nghiệp + Ghi chú
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Nghề nghiệp'),
                  _buildTextFormField(
                    controller: _occupationCtrl,
                    hint: 'Nhập nghề nghiệp',
                    prefixIcon: Icons.work_outline_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Ghi chú'),
                  _buildTextFormField(
                    controller: _notesCtrl,
                    hint: 'Nhập ghi chú',
                    prefixIcon: Icons.edit_note_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // ACTION BUTTONS
  // ===========================================================================
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Nút Hủy bỏ
        Expanded(
          child: GestureDetector(
            onTap: _cancel,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Hủy bỏ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Nút Lưu thành viên
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _save,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Lưu thành viên',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SHARED HELPERS
  // ===========================================================================

  /// Label text nhỏ phía trên input
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Input field dùng chung
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 16, color: AppColors.textMuted)
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primaryMedium,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  /// Date field với icon calendar
  Widget _buildDateField({
    required TextEditingController controller,
    required String hint,
  }) {
    return GestureDetector(
      onTap: () => _pickDate(controller),
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            filled: true,
            fillColor: AppColors.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primaryMedium,
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
