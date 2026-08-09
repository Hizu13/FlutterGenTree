/// 1. OBJECT NGÀY ÂM LỊCH
class LunarDate {
  final int day;
  final int month;
  final int year;

  const LunarDate({required this.day, required this.month, required this.year});

  String get formatted =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year.toString()}';

  String get displayShort =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')} Âm lịch';
}

/// 2. EVENT MODEL CHÍNH (ĐÃ LÀM SẠCH CÁC TRƯỜNG DƯ THỪA)
class EventModel {
  final String id;
  final String title;

  final LunarDate lunarDate;
  final DateTime? solarDate;
  final String note;
  final String creatorName;
  final String creatorAvatarUrl;
  final String dateRange;
  final String time;
  final DateTime date; // Ngày khớp với solarDate để hiển thị lịch
  final bool isNotified;

  EventModel({
    required this.id,
    required this.title,
    required this.dateRange,
    required this.time,
    required this.date,
    this.lunarDate = const LunarDate(day: 0, month: 0, year: 0),
    this.solarDate,
    this.note = '',
    this.creatorName = '',
    this.creatorAvatarUrl = '',
    this.isNotified = false,
  });

  // Getters hỗ trợ hiển thị UI
  String get dayString => date.day.toString().padLeft(2, '0');
  String get monthLabel => 'THÁNG ${date.month.toString().padLeft(2, '0')}';
  String get shortMonth => date.month.toString().padLeft(2, '0');
  String get yearLabel => date.year.toString();
  String get solarDateLabel {
    if (solarDate == null) return '';
    return '${solarDate!.day.toString().padLeft(2, '0')}/${solarDate!.month.toString().padLeft(2, '0')}/${solarDate!.year}';
  }

  // Hàm sao chép & chỉnh sửa object
  EventModel copyWith({
    String? id,
    String? title,
    LunarDate? lunarDate,
    DateTime? solarDate,
    String? note,
    String? creatorName,
    String? creatorAvatarUrl,
    String? dateRange,
    String? time,
    DateTime? date,
    bool? isNotified,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      lunarDate: lunarDate ?? this.lunarDate,
      solarDate: solarDate ?? this.solarDate,
      note: note ?? this.note,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      dateRange: dateRange ?? this.dateRange,
      time: time ?? this.time,
      date: date ?? this.date,
      isNotified: isNotified ?? this.isNotified,
    );
  }

  /// DỮ LIỆU MẪU ĐÃ ĐƯỢC TỐI ƯU
  static final List<EventModel> sampleEvents = [
    EventModel(
      id: 'evt_001',
      title: 'Giỗ Tổ Ông Nguyễn Văn A',
      lunarDate: const LunarDate(day: 15, month: 1, year: 2026),
      solarDate: DateTime(2026, 2, 12),
      date: DateTime(2026, 2, 12),
      dateRange: '15/01 Âm lịch → 12/02/2026',
      note: 'Cập nhật thông tin sự kiện',
      creatorName: 'Nguyễn Văn A',
      time: '09:00 - 11:00',
    ),
    EventModel(
      id: 'evt_002',
      title: 'Giỗ Tổ Ông Nguyễn Văn A',
      lunarDate: const LunarDate(day: 10, month: 1, year: 2026),
      solarDate: DateTime(2026, 2, 11),
      date: DateTime(2026, 2, 11),
      dateRange: '10/01 Âm lịch → 11/02/2026',
      note: 'Cập nhật thông tin sự kiện',
      creatorName: 'Nguyễn Văn A',
      time: '10:00 - 12:00',
    ),
    EventModel(
      id: 'evt_003',
      title: 'Lễ tảo mộ Xuân',
      lunarDate: const LunarDate(day: 23, month: 1, year: 2026),
      solarDate: DateTime(2026, 2, 20),
      date: DateTime(2026, 2, 20),
      dateRange: '23/01 Âm lịch → 20/02/2026',
      note: 'Chuẩn bị hương hoa và lễ vật',
      creatorName: 'Nguyễn Văn B',
      time: '08:30 - 10:00',
    ),
    EventModel(
      id: 'evt_004',
      title: 'Họp họ đầu Năm',
      lunarDate: const LunarDate(day: 30, month: 1, year: 2026),
      solarDate: DateTime(2026, 3, 1),
      date: DateTime(2026, 3, 1),
      dateRange: '30/01 Âm lịch → 01/03/2026',
      note: 'Kiểm tra danh sách thành viên và kế hoạch năm',
      creatorName: 'Nguyễn Văn C',
      time: '14:00 - 16:00',
    ),
    EventModel(
      id: 'evt_005',
      title: 'Giỗ Tổ Ông Nguyễn Văn C',
      lunarDate: const LunarDate(day: 28, month: 2, year: 2026),
      solarDate: DateTime(2026, 4, 12),
      date: DateTime(2026, 4, 12),
      dateRange: '28/02 Âm lịch → 12/04/2026',
      time: '09:30 - 11:30',
    ),
  ];
}
