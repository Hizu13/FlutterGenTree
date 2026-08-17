import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/event_model.dart';

class EventForm extends StatefulWidget {
  final EventModel? initialEvent;
  final String submitButtonText;
  final Function(EventModel event) onSubmit;

  const EventForm({
    super.key,
    this.initialEvent,
    this.submitButtonText = 'Yêu cầu phê duyệt',
    required this.onSubmit,
  });

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _noteController;

  int _lunarDay = 1;
  int _lunarMonth = 1;
  int _lunarYear = 2026;
  DateTime _solarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    _titleController = TextEditingController(text: event?.title ?? '');
    _noteController = TextEditingController(text: event?.note ?? '');

    if (event != null) {
      if (event.lunarDate.day > 0) _lunarDay = event.lunarDate.day;
      if (event.lunarDate.month > 0) _lunarMonth = event.lunarDate.month;
      if (event.lunarDate.year > 0) _lunarYear = event.lunarDate.year;
      _solarDate = event.solarDate ?? event.date;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Avatar & Tên sự kiện
            _buildHeaderSection(),
            const SizedBox(height: 20),

            // Tên sự kiện *
            _buildLabel('Tên sự kiện'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.event_note,
                  color: AppColors.primary,
                ),
                hintText: 'Nhập tên sự kiện',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập tên sự kiện';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Ngày Âm lịch * (3 Dropdowns)
            _buildLabel('Ngày Âm lịch'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDropdownDay()),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdownMonth()),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdownYear()),
              ],
            ),
            const SizedBox(height: 16),

            // Ngày Dương lịch (tương ứng)
            _buildLabel('Ngày Dương lịch (tương ứng)'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickSolarDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_solarDate.day.toString().padLeft(2, '0')}/${_solarDate.month.toString().padLeft(2, '0')}/${_solarDate.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.calendar_month,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Chú thích (nếu có)
            _buildLabel('Chú thích (nếu có)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Nhập chú thích (không bắt buộc)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Nút Yêu cầu phê duyệt
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleSubmit,
                icon: Transform.rotate(
                  angle: -0.35, // Xoay nghiêng icon máy bay
                  child: const Icon(
                    Icons.send_outlined,
                    size: 20,
                    color: Color(0xFF6B3812),
                  ),
                ),
                label: Text(
                  widget.submitButtonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B3812),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBE8D3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Chú thích icon khiên
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sự kiện sẽ được gửi đến người có thẩm quyền phê duyệt trước khi ghi nhận.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final title = _titleController.text.isNotEmpty
        ? _titleController.text
        : 'Tạo sự kiện mới';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceWarm,
            child: const Icon(Icons.event, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cập nhật thông tin sự kiện',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDropdownDay() {
    return DropdownButtonFormField<int>(
      value: _lunarDay,
      decoration: _inputDecoration('Ngày'),
      items: List.generate(
        30,
        (i) => i + 1,
      ).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
      onChanged: (val) => setState(() => _lunarDay = val ?? 1),
    );
  }

  Widget _buildDropdownMonth() {
    return DropdownButtonFormField<int>(
      value: _lunarMonth,
      decoration: _inputDecoration('Tháng'),
      items: List.generate(
        12,
        (i) => i + 1,
      ).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
      onChanged: (val) => setState(() => _lunarMonth = val ?? 1),
    );
  }

  Widget _buildDropdownYear() {
    return DropdownButtonFormField<int>(
      value: _lunarYear,
      decoration: _inputDecoration('Năm'),
      items: List.generate(
        10,
        (i) => 2024 + i,
      ).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
      onChanged: (val) => setState(() => _lunarYear = val ?? 2026),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  Future<void> _pickSolarDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _solarDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _solarDate = picked);
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      final newEvent = EventModel(
        id:
            widget.initialEvent?.id ??
            'evt_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        dateRange:
            '$_lunarDay/$_lunarMonth Âm lịch → ${_solarDate.day}/${_solarDate.month}/${_solarDate.year}',
        time: widget.initialEvent?.time ?? '08:00 - 10:00',
        date: _solarDate,
        solarDate: _solarDate,
        note: _noteController.text.trim(),
        lunarDate: LunarDate(
          day: _lunarDay,
          month: _lunarMonth,
          year: _lunarYear,
        ),
      );
      widget.onSubmit(newEvent);
    }
  }
}
