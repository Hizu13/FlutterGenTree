import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../../member/models/member_model.dart';
import '../../member/services/member_api_service.dart';
import '../models/transaction_model.dart';
import '../services/finance_api_service.dart';

class AddMeritScreen extends StatefulWidget {
  final bool canManage;
  final int? familyId;

  const AddMeritScreen({
    super.key,
    this.canManage = false,
    this.familyId,
  });

  @override
  State<AddMeritScreen> createState() => _AddMeritScreenState();
}

class _AddMeritScreenState extends State<AddMeritScreen> {
  final _eventController = TextEditingController();
  final _amountController = TextEditingController();
  final _personNameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Công đức');
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<MemberModel> _members = [];
  MemberModel? _selectedMember;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _eventController.dispose();
    _amountController.dispose();
    _personNameController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await MemberApiService.fetchAll(familyId: widget.familyId);
      if (mounted) {
        setState(() {
          _members = members;
          if (members.isNotEmpty) {
            _selectedMember = members.first;
            _personNameController.text = members.first.fullName;
          }
        });
      }
    } catch (_) {}
  }

  double _parseAmount(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '').replaceAll('đ', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  Future<void> _handleSubmit() async {
    final title = _eventController.text.trim();
    final amount = _parseAmount(_amountController.text);
    final personName = _personNameController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên công đức / sự kiện')),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }

    if (personName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập người công đức')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final memberId = _selectedMember?.id != null ? int.tryParse(_selectedMember!.id!) : null;

    final tx = TransactionModel(
      id: '',
      title: title,
      amount: amount,
      type: TransactionType.merit,
      personName: personName,
      category: _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : 'Công đức',
      date: _selectedDate,
      note: _noteController.text.trim(),
      familyId: widget.familyId,
      memberId: memberId,
      requiresApproval: !widget.canManage,
      status: widget.canManage ? 'approved' : 'pending',
    );

    final result = await FinanceApiService.createTransaction(tx);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null) {
      final msg = widget.canManage
          ? 'Đã ghi nhận khoản công đức thành công!'
          : 'Đã gửi yêu cầu phê duyệt khoản công đức!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thêm khoản công đức. Vui lòng thử lại!'),
          backgroundColor: AppColors.badgeRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.canManage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0x33FFFFFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.spa_outlined,
                color: AppColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isManager ? 'Thêm khoản công đức' : 'Yêu cầu thêm công đức',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Tên sự kiện / Mục đích công đức *'),
            _buildTextField(
              controller: _eventController,
              hintText: 'Nhập nội dung công đức (vd: Tu bổ từ đường, Đúc chuông...)',
              suffixIcon: const Icon(
                Icons.article_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Số tiền công đức *'),
            _buildTextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              hintText: 'Nhập số tiền (VNĐ)',
              suffixText: 'đ ',
              suffixIcon: const Icon(
                Icons.monetization_on_outlined,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Người công đức / Dâng hương *'),
            if (_members.isNotEmpty) ...[
              _buildMemberDropdown(),
              const SizedBox(height: 8),
            ],
            _buildTextField(
              controller: _personNameController,
              hintText: 'Tên người công đức (hoặc nhập tên tùy chỉnh)',
              suffixIcon: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Danh mục'),
            _buildTextField(
              controller: _categoryController,
              hintText: 'Danh mục (vd: Công đức tu bổ, Đúc chuông, Quỹ từ thiện...)',
              suffixIcon: const Icon(
                Icons.category_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Ngày giao dịch *'),
            _buildDatePicker(),
            const SizedBox(height: 16),

            _buildLabel('Chú thích (nếu có)'),
            _buildNoteField(),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isManager ? AppColors.primaryGold : const Color(0xFF6B3812),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : _handleSubmit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(
                        isManager ? Icons.add_circle_outline : Icons.send_outlined,
                        color: AppColors.white,
                        size: 18,
                      ),
                label: Text(
                  _isLoading
                      ? 'Đang xử lý...'
                      : (isManager ? 'Thêm khoản công đức' : 'Yêu cầu phê duyệt'),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isManager
                  ? 'Khoản công đức sẽ được cộng trực tiếp vào số dư quỹ dòng họ.'
                  : 'Khoản công đức sẽ được gửi đến Trưởng họ hoặc Biên tập viên để phê duyệt.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          suffixIcon: suffixIcon,
          suffixText: suffixText,
          suffixStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MemberModel>(
          value: _selectedMember,
          isExpanded: true,
          hint: const Text('Chọn thành viên trong gia phả'),
          items: _members
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text('${m.fullName} (Đời ${m.generation})'),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedMember = val;
                _personNameController.text = val.fullName;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Nhập ghi chú chi tiết...',
          hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }
}
