import 'package:flutter/material.dart';

class GenealogyForm extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final String? initialAddress;
  final String? initialNote;
  final DateTime? initialEstablishedDate;
  final DateTime? initialUpdatedDate;
  final VoidCallback? onSave;

  const GenealogyForm({
    super.key,
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialAddress,
    this.initialNote,
    this.initialEstablishedDate,
    this.initialUpdatedDate,
    this.onSave,
  });

  @override
  State<GenealogyForm> createState() => _GenealogyFormState();
}

class _GenealogyFormState extends State<GenealogyForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _addressController;
  late TextEditingController _noteController;

  late DateTime _establishedDate;
  late DateTime _updatedDate;

  // Bảng màu chuẩn thiết kế
  static const Color primaryBrown = Color(0xFF603813);
  static const Color primaryGold = Color(0xFFD4A373);
  static const Color scaffoldBg = Color(0xFFF9F7F2);
  static const Color cardBg = Colors.white;
  static const Color inputBg = Color(0xFFF5F3EF);
  static const Color borderColor = Color(0xFFE8E2D8);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _addressController = TextEditingController(
      text: widget.initialAddress ?? 'Hà nội, Việt Nam',
    );
    _noteController = TextEditingController(text: widget.initialNote ?? '');

    _establishedDate = widget.initialEstablishedDate ?? DateTime(2026, 1, 27);
    _updatedDate = widget.initialUpdatedDate ?? DateTime(2026, 3, 24);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF603813), Color(0xFF7A4B1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              // 1. Thẻ Ảnh đại diện
              _buildAvatarCard(),
              const SizedBox(height: 16),

              // 2. Thẻ Thông tin cơ bản
              _buildBasicInfoCard(),
              const SizedBox(height: 16),

              // 3. Thẻ Ghi chú
              _buildNoteCard(),
              const SizedBox(height: 28),

              // 4. Hàng nút Thao tác
              _buildActionButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Khối 1: Avatar
  Widget _buildAvatarCard() {
    return _buildContainerCard(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFAF2E6),
                  border: Border.all(color: primaryGold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBrown.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: primaryBrown,
                ),
              ),
              Positioned(
                bottom: 0,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryBrown,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ảnh đại diện',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Hỗ trợ JPG, PNG tối đa 5MB',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: primaryBrown,
                  ),
                  label: const Text(
                    'Thay ảnh',
                    style: TextStyle(
                      color: primaryBrown,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryBrown, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Khối 2: Thông tin cơ bản
  Widget _buildBasicInfoCard() {
    return _buildContainerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryBrown.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: primaryBrown,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Thông tin cơ bản',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: borderColor),
          ),
          _buildFormRow(
            label: 'Tên gia phả',
            icon: Icons.person_outline_rounded,
            child: TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 13.5),
              decoration: _inputDecoration('Dòng họ...'),
            ),
          ),
          const SizedBox(height: 12),
          _buildFormRow(
            label: 'Mô tả chi tiết',
            icon: Icons.article_outlined,
            child: TextFormField(
              controller: _descController,
              style: const TextStyle(fontSize: 13.5),
              decoration: _inputDecoration('Nhập mô tả chi tiết...'),
            ),
          ),
          const SizedBox(height: 12),
          _buildFormRow(
            label: 'Cập nhật gần nhất',
            icon: Icons.calendar_today_outlined,
            child: _buildDatePickerBox(_updatedDate, (picked) {
              setState(() => _updatedDate = picked);
            }),
          ),
          const SizedBox(height: 12),
          _buildFormRow(
            label: 'Ngày thành lập',
            icon: Icons.event_note_outlined,
            child: _buildDatePickerBox(_establishedDate, (picked) {
              setState(() => _establishedDate = picked);
            }),
          ),
          const SizedBox(height: 12),
          _buildFormRow(
            label: 'Địa chỉ tổ tiên',
            icon: Icons.location_on_outlined,
            child: TextFormField(
              controller: _addressController,
              style: const TextStyle(fontSize: 13.5),
              decoration: _inputDecoration('Nhập địa chỉ').copyWith(
                suffixIcon: const Icon(
                  Icons.star_rounded,
                  color: primaryBrown,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Khối 3: Ghi chú
  Widget _buildNoteCard() {
    return _buildContainerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryBrown.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.note_alt_outlined,
                  color: primaryBrown,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ghi chú',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                  color: primaryBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            maxLines: 4,
            maxLength: 500,
            style: const TextStyle(fontSize: 13.5),
            onChanged: (val) => setState(() {}),
            decoration: _inputDecoration('Thông tin thêm về dòng họ...')
                .copyWith(
                  counterStyle: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // Nút Hủy và Lưu
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.cancel_outlined,
              size: 18,
              color: primaryBrown,
            ),
            label: const Text(
              'Hủy',
              style: TextStyle(
                color: primaryBrown,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: primaryBrown, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              widget.onSave?.call();
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'Lưu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: primaryBrown.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildContainerCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFormRow({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: primaryBrown.withOpacity(0.8)),
        const SizedBox(width: 6),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
      filled: true,
      fillColor: inputBg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryBrown, width: 1.2),
      ),
    );
  }

  Widget _buildDatePickerBox(DateTime date, Function(DateTime) onPicked) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(1800),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: primaryBrown,
                    onPrimary: Colors.white,
                    surface: cardBg,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: primaryBrown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
