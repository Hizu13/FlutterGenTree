import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../widgets/delete_event_dialog.dart';
import '../widgets/event_calendar.dart';
import '../widgets/event_card.dart';
import '../widgets/event_tab_bar.dart';

// Import 2 màn hình Form Thêm & Sửa
import 'add_event_screen.dart';
import 'edit_event_screen.dart';

class EventScreen extends StatefulWidget {
  final List<EventModel>? events;
  final Function(EventModel)? onAddEvent;
  final Function(EventModel)? onEditEvent;
  final Function(String)? onDeleteEvent;
  final Function(EventModel)? onViewEvent;

  const EventScreen({
    super.key,
    this.events,
    this.onAddEvent,
    this.onEditEvent,
    this.onDeleteEvent,
    this.onViewEvent,
  });

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  int _selectedTab = 2;
  int _selectedDay = 0;

  late List<EventModel> _currentEvents;

  final List<String> _tabLabels = ['Tháng này', 'Sắp tới', 'Tất cả'];
  final List<String> _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final List<int> _days = [20, 21, 22, 23, 24, 25, 26];

  @override
  void initState() {
    super.initState();
    _currentEvents = List.from(
      (widget.events != null && widget.events!.isNotEmpty)
          ? widget.events!
          : EventModel.sampleEvents,
    );
  }

  @override
  void didUpdateWidget(covariant EventScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events != oldWidget.events && widget.events != null) {
      setState(() {
        _currentEvents = List.from(widget.events!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();

    return Stack(
      children: [
        Container(
          color: AppColors.background,
          child: Column(
            children: [
              _buildAppBar(context),
              const SizedBox(height: 12),
              _buildTabBar(),
              const SizedBox(height: 12),
              _buildWeekCalendar(),
              const SizedBox(height: 12),
              Expanded(child: _buildEventList(filteredEvents)),
            ],
          ),
        ),
        Positioned(right: 20, bottom: 24, child: _buildAddButton()),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    const rightActionsWidth = 86.0;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        18 + MediaQuery.of(context).padding.top,
        16,
        18,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: rightActionsWidth),
          const Text(
            'Sự kiện',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            width: rightActionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _handleNotificationClick,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _handleMoreClick,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return EventTabBar(
      labels: _tabLabels,
      selectedIndex: _selectedTab,
      onTabSelected: (index) => setState(() {
        _selectedTab = index;
        _selectedDay = 0;
      }),
    );
  }

  Widget _buildWeekCalendar() {
    return EventCalendar(
      weekdays: _weekdays,
      days: _days,
      selectedDay: _selectedDay,
      onDaySelected: (index) => setState(() => _selectedDay = index),
    );
  }

  Widget _buildAddButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.primaryGold,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        onPressed: _handleAddEvent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  List<EventModel> _getFilteredEvents() {
    if (_selectedTab == 2) {
      return _currentEvents;
    }
    return EventService.getFilteredEvents(
      _currentEvents,
      _selectedTab,
      _selectedTab < 2 ? _days[_selectedDay] : null,
    );
  }

  Widget _buildEventList(List<EventModel> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 48,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có sự kiện trong ngày đã chọn.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => EventCard(
        event: events[index],
        onEdit: (e) => _handleEditEvent(e),
        onDelete: (e) => _handleDeleteEvent(e),
      ),
    );
  }

  // ==================== HANDLERS ====================

  // 1. Thêm sự kiện
  void _handleAddEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(
          onAddEvent: (newEvent) {
            setState(() {
              _currentEvents.add(newEvent);
            });
            widget.onAddEvent?.call(newEvent);
          },
        ),
      ),
    );
  }

  // 2. Chỉnh sửa sự kiện
  void _handleEditEvent(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(
          event: event,
          onEditEvent: (updatedEvent) {
            setState(() {
              final index = _currentEvents.indexWhere(
                (e) => e.id == updatedEvent.id,
              );
              if (index != -1) {
                _currentEvents[index] = updatedEvent;
              }
            });
            widget.onEditEvent?.call(updatedEvent);
          },
        ),
      ),
    );
  }

  // 3. Xóa sự kiện
  void _handleDeleteEvent(EventModel event) {
    DeleteEventDialog.show(
      context,
      event: event,
      onConfirm: () {
        setState(() {
          _currentEvents.removeWhere((e) => e.id == event.id);
        });
        widget.onDeleteEvent?.call(event.id);
      },
    );
  }

  // ==================== THÔNG BÁO ====================

  // Xử lý khi nhấn vào nút chuông thông báo
  void _handleNotificationClick() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh gạch ngang mỏng phía trên BottomSheet
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thông báo sự kiện',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // THÔNG BÁO 1
            _buildNotificationItem(
              title: 'Sắp diễn ra: Giỗ Tổ Ông Nguyễn Văn A',
              subtitle:
                  'Sự kiện sẽ diễn ra vào ngày 12/02/2026 (15/01 Âm lịch)',
              time: '10 phút trước',
              icon: Icons.event_available_rounded,
            ),
            const SizedBox(height: 10),

            // THÔNG BÁO 2
            _buildNotificationItem(
              title: 'Nhắc nhở: Lễ tảo mộ Xuân',
              subtitle: 'Chuẩn bị hương hoa và lễ vật cho ngày 20/02/2026',
              time: '1 giờ trước',
              icon: Icons.notifications_active_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // Widget vẽ từng item thông báo
  Widget _buildNotificationItem({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMoreClick() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tùy chọn khác')));
  }
}
