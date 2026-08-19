import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../../../utils/lunar_solar_converter.dart';
import '../models/event_model.dart';

class EventForm extends StatefulWidget {
  final EventModel? initialEvent;
  final bool canManage;
  final String? customSubmitText;
  final Function(EventModel event) onSubmit;

  const EventForm({
    super.key,
    this.initialEvent,
    this.canManage = false,
    this.customSubmitText,
    required this.onSubmit,
  });

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _noteController;

  int _lunarDay = 1;
  int _lunarMonth = 1;
  int _lunarYear = 2026;
  DateTime _solarDate = DateTime.now();
  String _eventType = 'custom';

  TimeOfDay _timeStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _timeEnd = const TimeOfDay(hour: 11, minute: 30);

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    _titleController = TextEditingController(text: event?.title ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _noteController = TextEditingController(text: event?.note ?? '');

    if (event != null) {
      _eventType = event.eventType;
      if (event.lunarDate.day > 0) _lunarDay = event.lunarDate.day;
      if (event.lunarDate.month > 0) _lunarMonth = event.lunarDate.month;
      if (event.lunarDate.year > 0) _lunarYear = event.lunarDate.year;
      _solarDate = event.solarDate ?? event.date;

      // Phân tích giờ từ event.time (vd: "08:00 - 11:30")
      if (event.time.contains('-')) {
        final parts = event.time.split('-');
        final startParts = parts[0].trim().split(':');
        final endParts = parts[1].trim().split(':');
        if (startParts.length == 2) {
          final h = int.tryParse(startParts[0]) ?? 8;
          final m = int.tryParse(startParts[1]) ?? 0;
          _timeStart = TimeOfDay(hour: h, minute: m);
        }
        if (endParts.length == 2) {
          final h = int.tryParse(endParts[0]) ?? 11;
          final m = int.tryParse(endParts[1]) ?? 30;
          _timeEnd = TimeOfDay(hour: h, minute: m);
        }
      }
    } else {
      // Khởi tạo ngày hôm nay và tự động tính ngày Âm lịch tương ứng
      final now = DateTime.now();
      _solarDate = now;
      final lunar = LunarSolarConverter.solarToLunar(now);
      _lunarDay = lunar.day;
      _lunarMonth = lunar.month;
      _lunarYear = lunar.year;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ==================== TỰ ĐỘNG ĐỒNG BỘ ÂM <-> DƯƠNG ====================

  /// Khi thay đổi Ngày / Tháng / Năm Âm lịch -> Tự động tính ngày Dương lịch tương ứng
  void _syncSolarFromLunar() {
    try {
      final solar = LunarSolarConverter.lunarToSolar(_lunarDay, _lunarMonth, _lunarYear);
      setState(() {
        _solarDate = solar;
      });
    } catch (e) {
      debugPrint('[!] Error syncing solar date from lunar: $e');
    }
  }

  /// Khi chọn Ngày Dương lịch từ DatePicker -> Tự động tính ngày Âm lịch tương ứng
  void _syncLunarFromSolar(DateTime picked) {
    try {
      final lunar = LunarSolarConverter.solarToLunar(picked);
      setState(() {
        _solarDate = picked;
        _lunarDay = lunar.day;
        _lunarMonth = lunar.month;
        _lunarYear = lunar.year;
      });
    } catch (e) {
      debugPrint('[!] Error syncing lunar date from solar: $e');
    }
  }

  // Hộp thoại chọn Ngày Dương lịch
  Future<void> _pickSolarDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _solarDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _syncLunarFromSolar(picked);
    }
  }

  // Hộp thoại chọn Ngày Âm lịch
  Future<void> _pickLunarDate() async {
    int tempDay = _lunarDay;
    int tempMonth = _lunarMonth;
    int tempYear = _lunarYear;

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentYear = DateTime.now().year;
          final startYear = tempYear < 1950 ? tempYear - 2 : 1950;
          final endYear = tempYear > currentYear + 30 ? tempYear + 5 : currentYear + 30;
          final years = List.generate(endYear - startYear + 1, (i) => startYear + i);

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn ngày Âm lịch',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Ngày Âm lịch (1..30)
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        value: tempDay.clamp(1, 30),
                        decoration: InputDecoration(
                          labelText: 'Ngày',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: List.generate(30, (i) => i + 1)
                            .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempDay = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tháng Âm lịch (1..12)
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        value: tempMonth.clamp(1, 12),
                        decoration: InputDecoration(
                          labelText: 'Tháng',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempMonth = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Năm Âm lịch
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: tempYear,
                        decoration: InputDecoration(
                          labelText: 'Năm',
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: years
                            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => tempYear = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx, {'day': tempDay, 'month': tempMonth, 'year': tempYear});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Xác nhận',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        _lunarDay = result['day']!;
        _lunarMonth = result['month']!;
        _lunarYear = result['year']!;
      });
      _syncSolarFromLunar();
    }
  }

  // Chọn Giờ bắt đầu
  Future<void> _pickTimeStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeStart,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _timeStart = picked;
      });
    }
  }

  // Chọn Giờ kết thúc
  Future<void> _pickTimeEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _timeEnd = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.canManage;
    final submitText = widget.customSubmitText ??
        (isManager ? 'Thêm sự kiện' : 'Yêu cầu phê duyệt');

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Preview Card
            _buildHeaderSection(),
            const SizedBox(height: 20),

            // Tên sự kiện *
            _buildLabel('Tên sự kiện *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                hintText: 'Nhập tên sự kiện (vd: Giỗ họ, Liên hoan...)',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
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
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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

            // Ngày Âm lịch (Giao diện đơn ô đồng nhất với Dương lịch)
            _buildLabel('Ngày Âm lịch'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickLunarDate,
              borderRadius: BorderRadius.circular(10),
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
                          Icons.calendar_month_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_lunarDay.toString().padLeft(2, '0')}/${_lunarMonth.toString().padLeft(2, '0')}/$_lunarYear',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.edit_calendar_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ngày Dương lịch (tương ứng)
            _buildLabel('Ngày Dương lịch (tương ứng)'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickSolarDate,
              borderRadius: BorderRadius.circular(10),
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
                          Icons.calendar_month_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_solarDate.day.toString().padLeft(2, '0')}/${_solarDate.month.toString().padLeft(2, '0')}/${_solarDate.year}',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.edit_calendar_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Khung giờ diễn ra: Giờ bắt đầu & Giờ kết thúc
            _buildLabel('Thời gian diễn ra'),
            const SizedBox(height: 8),
            Row(
              children: [
                // Giờ bắt đầu
                Expanded(
                  child: InkWell(
                    onTap: _pickTimeStart,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bắt đầu',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                _formatTimeOfDay(_timeStart),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('→', style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                const SizedBox(width: 10),
                // Giờ kết thúc
                Expanded(
                  child: InkWell(
                    onTap: _pickTimeEnd,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kết thúc',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                _formatTimeOfDay(_timeEnd),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Địa điểm tổ chức
            _buildLabel('Địa điểm tổ chức (nếu có)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                hintText: 'Nhập địa điểm (vd: Nhà thờ họ, Từ đường, Nhà hàng...)',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
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
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Chú thích (nếu có)
            _buildLabel('Chú thích (nếu có)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              onChanged: (_) => setState(() {}),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Nút bấm: Admin/Editor hiển thị "Thêm sự kiện", Member hiển thị "Yêu cầu phê duyệt"
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleSubmit,
                icon: isManager
                    ? const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 22,
                        color: Colors.white,
                      )
                    : Transform.rotate(
                        angle: -0.35,
                        child: const Icon(
                          Icons.send_rounded,
                          size: 19,
                          color: Color(0xFF6B3812),
                        ),
                      ),
                label: Text(
                  submitText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isManager ? Colors.white : const Color(0xFF6B3812),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isManager
                      ? AppColors.primaryGold
                      : const Color(0xFFFBE8D3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isManager ? 2 : 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Dòng chú thích bên dưới
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isManager
                      ? Icons.verified_rounded
                      : Icons.shield_outlined,
                  size: 18,
                  color: isManager ? AppColors.success : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isManager
                      ? 'Sự kiện sẽ được ghi nhận và hiển thị trực tiếp cho toàn thể gia phả.'
                      : 'Sự kiện sẽ được gửi đến người có thẩm quyền phê duyệt trước khi ghi nhận.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isManager ? AppColors.textPrimary : AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==================== CÁC PHẦN TỬ GIAO DIỆN CON ====================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildHeaderSection() {
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.selfPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : 'Tên sự kiện',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  note.isNotEmpty ? note : 'Cập nhật thông tin sự kiện',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final dateRange =
          '${_lunarDay.toString().padLeft(2, '0')}/${_lunarMonth.toString().padLeft(2, '0')} Âm lịch → ${_solarDate.day.toString().padLeft(2, '0')}/${_solarDate.month.toString().padLeft(2, '0')}/${_solarDate.year}';

      final timeStr = '${_formatTimeOfDay(_timeStart)} - ${_formatTimeOfDay(_timeEnd)}';

      final event = EventModel(
        id: widget.initialEvent?.id ?? '',
        title: _titleController.text.trim(),
        eventType: _eventType,
        lunarDate: LunarDate(
          day: _lunarDay,
          month: _lunarMonth,
          year: _lunarYear,
        ),
        solarDate: _solarDate,
        date: _solarDate,
        dateRange: dateRange,
        location: _locationController.text.trim(),
        note: _noteController.text.trim(),
        creatorName: 'Tôi',
        time: timeStr,
      );
      widget.onSubmit(event);
    }
  }
}
