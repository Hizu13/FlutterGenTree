import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../widgets/event_card.dart';
import '../widgets/event_calendar.dart';
import '../widgets/event_tab_bar.dart';
import '../widgets/delete_event_dialog.dart';

// Import 2 màn hình Form Thêm & Sửa
import 'add_event_screen.dart';
import 'edit_event_screen.dart';

class EventScreen extends StatefulWidget {
  final List<EventModel> events;
  final Function(EventModel)? onAddEvent;
  final Function(EventModel)? onEditEvent;
  final Function(String)? onDeleteEvent;
  final Function(EventModel)? onViewEvent;

  const EventScreen({
    super.key,
    required this.events,
    this.onAddEvent,
    this.onEditEvent,
    this.onDeleteEvent,
    this.onViewEvent,
  });

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  int _selectedTab = 1;
  int _selectedDay = 0;

  final List<String> _tabLabels = ['Tháng này', 'Sắp tới', 'Tất cả'];
  final List<String> _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final List<int> _days = [20, 21, 22, 23, 24, 25, 26];

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
    return EventService.getFilteredEvents(
      widget.events,
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

  // 1. Mở màn hình THÊM sự kiện
  void _handleAddEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(
          onAddEvent: (newEvent) {
            widget.onAddEvent?.call(newEvent);
          },
        ),
      ),
    );
  }

  // 2. Mở màn hình SỬA sự kiện
  void _handleEditEvent(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(
          event: event,
          onEditEvent: (updatedEvent) {
            widget.onEditEvent?.call(updatedEvent);
          },
        ),
      ),
    );
  }

  // 3. Mở dialog XÓA sự kiện
  void _handleDeleteEvent(EventModel event) {
    DeleteEventDialog.show(
      context,
      event: event,
      onConfirm: () {
        widget.onDeleteEvent?.call(event.id);
      },
    );
  }

  void _handleNotificationClick() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Thông báo sự kiện')));
  }

  void _handleMoreClick() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tùy chọn khác')));
  }
}
