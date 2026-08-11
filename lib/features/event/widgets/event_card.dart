import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/event_model.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final Function(EventModel)? onView;
  final Function(EventModel)? onEdit;
  final Function(EventModel)? onDelete;

  const EventCard({
    super.key,
    required this.event,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 1. DÒNG 2: Xử lý Note (Chỉ dùng event.note, bỏ hẳn subtitle)
    final note = event.note;
    final String secondLineText = (note != null && note.trim().isNotEmpty)
        ? note
        : 'Chưa có chú thích';

    // 2. DÒNG 3: Xử lý solarDate (Cung cấp fallback nếu solarDate bị null)
    final solar = event.solarDate ?? event.date;
    final String dateText = event.dateRange.isNotEmpty
        ? event.dateRange
        : '${event.lunarDate.day.toString().padLeft(2, '0')}/${event.lunarDate.month.toString().padLeft(2, '0')} Âm lịch • ${solar.day.toString().padLeft(2, '0')}/${solar.month.toString().padLeft(2, '0')}/${solar.year}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Lịch tròn bên trái
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFAF3EB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF6B3812),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Khối nội dung 3 dòng
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // DÒNG 1: Tên sự kiện
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C1810),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // DÒNG 2: Note / Chú thích
                Text(
                  secondLineText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // DÒNG 3: Ngày Âm lịch & Dương lịch
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu 3 chấm góc phải
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onSelected: (value) {
              if (value == 'view') onView?.call(event);
              if (value == 'edit') onEdit?.call(event);
              if (value == 'delete') onDelete?.call(event);
            },
            itemBuilder: (context) => [
              if (onView != null)
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Xem chi tiết'),
                    ],
                  ),
                ),
              if (onEdit != null)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Sửa'),
                    ],
                  ),
                ),
              if (onDelete != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
