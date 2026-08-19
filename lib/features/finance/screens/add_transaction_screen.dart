import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../../member/models/member_model.dart';
import '../../member/services/member_api_service.dart';
import '../models/transaction_model.dart';
import '../services/finance_api_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final bool canManage;
  final int? familyId;
  final TransactionType initialType;

  const AddTransactionScreen({
    super.key,
    this.canManage = false,
    this.familyId,
    this.initialType = TransactionType.income,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _personNameController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _selectedType;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<MemberModel> _members = [];
  MemberModel? _selectedMember;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType == TransactionType.all
        ? TransactionType.income
        : widget.initialType;
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _personNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await MemberApiService.fetchAll(familyId: widget.familyId);
      if (mounted) {
        setState(() {
          _members = members;
        });
      }
    } catch (_) {}
  }

  double _parseAmount(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '').replaceAll('đ', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  String get _categoryName {
    switch (_selectedType) {
      case TransactionType.income:
        return 'Khoản thu';
      case TransactionType.expense:
        return 'Khoản chi';
      case TransactionType.merit:
        return 'Công đức';
      default:
        return 'Khoản thu';
    }
  }

  String get _screenTitle {
    final action = widget.canManage ? 'Thêm' : 'Yêu cầu thêm';
    switch (_selectedType) {
      case TransactionType.income:
        return '$action khoản thu';
      case TransactionType.expense:
        return '$action khoản chi';
      case TransactionType.merit:
        return '$action công đức';
      default:
        return '$action thu chi';
    }
  }

  String get _titleHintText {
    switch (_selectedType) {
      case TransactionType.income:
        return 'Nhập tên khoản thu (vd: Thu quỹ họ năm 2026, Quỹ khuyến học...)';
      case TransactionType.expense:
        return 'Nhập tên khoản chi (vd: Mua vật tư xây dựng, Tiệc giỗ họ...)';
      case TransactionType.merit:
        return 'Nhập nội dung công đức (vd: Tu bổ từ đường, Đúc chuông...)';
      default:
        return 'Nhập tên giao dịch';
    }
  }

  String get _personLabel {
    switch (_selectedType) {
      case TransactionType.income:
        return 'Nguồn tiền / Người nộp *';
      case TransactionType.expense:
        return 'Người thực hiện chi / Đại diện *';
      case TransactionType.merit:
        return 'Người công đức / Dâng hương *';
      default:
        return 'Người thực hiện *';
    }
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final amount = _parseAmount(_amountController.text);
    final personName = _personNameController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập tên $_categoryName')),
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
        SnackBar(content: Text('Vui lòng nhập $_personLabel')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final memberId = _selectedMember?.id != null ? int.tryParse(_selectedMember!.id!) : null;

    final tx = TransactionModel(
      id: '',
      title: title,
      amount: amount,
      type: _selectedType,
      personName: personName,
      category: _categoryName,
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
          ? 'Đã ghi nhận $_categoryName thành công!'
          : 'Đã gửi yêu cầu phê duyệt $_categoryName!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thêm giao dịch. Vui lòng thử lại!'),
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
              child: Icon(
                _selectedType == TransactionType.income
                    ? Icons.download
                    : _selectedType == TransactionType.expense
                        ? Icons.shopping_basket_outlined
                        : Icons.spa_outlined,
                color: AppColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _screenTitle,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
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
            // 1. CHỌN LOẠI DANH MỤC (KHOẢN THU / KHOẢN CHI / CÔNG ĐỨC)
            _buildLabel('Loại danh mục *'),
            _buildTypeSelector(),
            const SizedBox(height: 16),

            // 2. TÊN GIAO DỊCH / NỘI DUNG
            _buildLabel('Tên sự kiện / $_categoryName *'),
            _buildTextField(
              controller: _titleController,
              hintText: _titleHintText,
              suffixIcon: const Icon(
                Icons.article_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            // 3. SỐ TIỀN
            _buildLabel('Số tiền *'),
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

            // 4. NGUỒN TIỀN / NGƯỜI NỘP (CHỈ 1 Ô DUY NHẤT: VỪA NHẬP VỪA CHỌN GỢI Ý)
            _buildLabel(_personLabel),
            _buildPersonAutocompleteField(),
            const SizedBox(height: 16),

            // 5. NGÀY GIAO DỊCH
            _buildLabel('Ngày giao dịch *'),
            _buildDatePicker(),
            const SizedBox(height: 16),

            // 6. CHÚ THÍCH
            _buildLabel('Chú thích (nếu có)'),
            _buildNoteField(),
            const SizedBox(height: 24),

            // 7. NÚT SUBMIT
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isManager ? const Color(0xFF6B3812) : AppColors.primaryGold,
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
                      : (isManager ? 'Lưu $_categoryName' : 'Yêu cầu phê duyệt'),
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
                  ? 'Giao dịch sẽ tự động cập nhật vào mục $_categoryName và tính vào số dư quỹ.'
                  : 'Giao dịch sẽ được gửi đến Trưởng họ hoặc Biên tập viên để phê duyệt.',
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

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildTypeOption(
            type: TransactionType.income,
            title: 'Khoản thu',
            icon: Icons.download,
            activeColor: AppColors.income,
            activeBg: AppColors.incomeBg,
          ),
          const SizedBox(width: 4),
          _buildTypeOption(
            type: TransactionType.expense,
            title: 'Khoản chi',
            icon: Icons.shopping_basket_outlined,
            activeColor: AppColors.badgeRed,
            activeBg: AppColors.expenseBg,
          ),
          const SizedBox(width: 4),
          _buildTypeOption(
            type: TransactionType.merit,
            title: 'Công đức',
            icon: Icons.spa_outlined,
            activeColor: AppColors.primaryGold,
            activeBg: AppColors.donationBg,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required TransactionType type,
    required String title,
    required IconData icon,
    required Color activeColor,
    required Color activeBg,
  }) {
    final isSelected = _selectedType == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: activeColor, width: 1.2)
                : Border.all(color: Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ô DUY NHẤT: Vừa gõ tự do tên người, vừa gợi ý/chọn thành viên trong gia phả
  Widget _buildPersonAutocompleteField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<MemberModel>(
          textEditingController: _personNameController,
          focusNode: FocusNode(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return _members;
            }
            final query = textEditingValue.text.toLowerCase();
            return _members.where((MemberModel m) {
              return m.fullName.toLowerCase().contains(query);
            });
          },
          displayStringForOption: (MemberModel m) => m.fullName,
          onSelected: (MemberModel selection) {
            setState(() {
              _selectedMember = selection;
              _personNameController.text = selection.fullName;
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Nhập hoặc chọn thành viên...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: PopupMenuButton<MemberModel>(
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    tooltip: 'Chọn từ danh sách gia phả',
                    onSelected: (MemberModel m) {
                      setState(() {
                        _selectedMember = m;
                        _personNameController.text = m.fullName;
                      });
                    },
                    itemBuilder: (ctx) {
                      return _members.map((m) {
                        return PopupMenuItem<MemberModel>(
                          value: m,
                          child: Text('${m.fullName} (Đời ${m.generation})'),
                        );
                      }).toList();
                    },
                  ),
                ),
                onChanged: (val) {
                  // Nếu người dùng tự gõ khác tên đã chọn
                  if (_selectedMember != null && _selectedMember!.fullName != val) {
                    _selectedMember = null;
                  }
                },
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          option.fullName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Đời thứ ${option.generation}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        leading: const Icon(Icons.person, size: 18, color: AppColors.primary),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
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
