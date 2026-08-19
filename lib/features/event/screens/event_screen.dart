import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../../auth/models/auth_request_model.dart';
import '../../auth/services/auth_service.dart';
import '../../family/models/family_model.dart';
import '../../family/services/family_api_service.dart';
import '../models/event_model.dart';
import '../services/event_api_service.dart';
import '../widgets/delete_event_dialog.dart';
import '../widgets/event_card.dart';
import '../widgets/event_tab_bar.dart';
import 'add_event_screen.dart';
import 'edit_event_screen.dart';

class EventScreen extends StatefulWidget {
  final List<EventModel>? events;
  final int? familyId;
  final Function(EventModel)? onAddEvent;
  final Function(EventModel)? onEditEvent;
  final Function(String)? onDeleteEvent;
  final Function(EventModel)? onViewEvent;

  const EventScreen({
    super.key,
    this.events,
    this.familyId,
    this.onAddEvent,
    this.onEditEvent,
    this.onDeleteEvent,
    this.onViewEvent,
  });

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  int _selectedTab = 2; // 0: Trong 7 ngày tới, 1: Tháng này, 2: Tất cả
  bool _isLoading = false;
  int? _activeFamilyId;

  UserModel? _currentUser;
  FamilyModel? _currentFamily;
  List<EventModel> _currentEvents = [];

  final List<String> _tabLabels = ['7 ngày tới', 'Tháng này', 'Tất cả'];

  // ==================== PHÂN QUYỀN TRƯỞNG HỌ & EDITOR ====================
  bool get _isAdmin {
    final famRole = _currentFamily?.userRole;
    final userRole = _currentUser?.role;
    final String role = (famRole ?? userRole ?? 'member').toLowerCase();
    if (role == 'admin' || role == 'owner') return true;
    if (_currentFamily?.ownerId != null &&
        _currentUser?.id != null &&
        _currentFamily!.ownerId == _currentUser!.id) {
      return true;
    }
    return false;
  }

  bool get _isEditor {
    final famRole = _currentFamily?.userRole;
    final userRole = _currentUser?.role;
    final String role = (famRole ?? userRole ?? 'member').toLowerCase();
    return role == 'editor';
  }

  /// Chỉ Trưởng họ (Admin/Owner) hoặc Editor mới có quyền Thêm, Sửa, Xóa sự kiện
  bool get _canManage => _isAdmin || _isEditor;

  @override
  void initState() {
    super.initState();
    _activeFamilyId = widget.familyId;
    _currentEvents = widget.events != null ? List.from(widget.events!) : [];
    _loadUserAndFamilyInfo();
    _loadEvents();
  }

  Future<void> _loadUserAndFamilyInfo() async {
    final user = await AuthService.getSavedUser();
    final family = await FamilyApiService.getCurrentFamily();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _currentFamily = family;
        if (_activeFamilyId == null && family != null) {
          _activeFamilyId = family.id;
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant EventScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.familyId != oldWidget.familyId) {
      _activeFamilyId = widget.familyId;
      _loadUserAndFamilyInfo();
      _loadEvents();
    } else if (widget.events != oldWidget.events && widget.events != null) {
      setState(() {
        _currentEvents = List.from(widget.events!);
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    // Nếu chưa có familyId, lấy từ active family cache
    if (_activeFamilyId == null) {
      final family = await FamilyApiService.getCurrentFamily();
      if (family != null) {
        _activeFamilyId = family.id;
        _currentFamily = family;
      }
    }

    final events = await EventApiService.getEvents(
      familyId: _activeFamilyId,
      autoSync: true,
    );

    if (mounted) {
      setState(() {
        _currentEvents = events;
        _isLoading = false;
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
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryMedium),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        color: AppColors.primaryMedium,
                        child: _buildEventList(filteredEvents),
                      ),
              ),
            ],
          ),
        ),
        // Nút thêm sự kiện / yêu cầu phê duyệt sự kiện
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
                      color: Colors.white.withValues(alpha: 0.18),
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
                  onTap: _handleSyncClick,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.sync_rounded,
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
      }),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedTab) {
      case 0: // Trong 7 ngày tới
        final next7Days = today.add(const Duration(days: 7, hours: 23, minutes: 59, seconds: 59));
        return _currentEvents.where((e) {
          final date = e.solarDate ?? e.date;
          final d = DateTime(date.year, date.month, date.day);
          return !d.isBefore(today) && !d.isAfter(next7Days);
        }).toList();

      case 1: // Tháng này
        return _currentEvents.where((e) {
          final date = e.solarDate ?? e.date;
          return date.month == now.month && date.year == now.year;
        }).toList();

      case 2: // Tất cả
      default:
        return _currentEvents;
    }
  }

  Widget _buildEventList(List<EventModel> events) {
    if (events.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Không có sự kiện trong danh mục đã chọn.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => EventCard(
        event: events[index],
        canManage: _canManage,
        onView: (e) => _handleViewEvent(e),
        onEdit: (e) => _handleEditEvent(e),
        onDelete: (e) => _handleDeleteEvent(e),
      ),
    );
  }

  // ==================== HANDLERS ====================

  // 0. Xem chi tiết sự kiện
  void _handleViewEvent(EventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              children: [
                Icon(
                  event.isBirthday
                      ? Icons.cake_rounded
                      : (event.isDeathAnniversary ? Icons.temple_buddhist_rounded : Icons.event_available_rounded),
                  color: AppColors.primary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(event.time, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(event.dateRange, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
              ],
            ),
            if (event.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(event.note, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    widget.onViewEvent?.call(event);
  }

  // 1. Thêm sự kiện (Admin/Editor thêm trực tiếp, Member gửi yêu cầu phê duyệt)
  void _handleAddEvent() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(
          canManage: _canManage,
          onAddEvent: (newEvent) async {
            final toCreate = newEvent.copyWith(familyId: _activeFamilyId);
            final created = await EventApiService.createEvent(toCreate);
            if (mounted) {
              if (created != null) {
                setState(() {
                  _currentEvents.insert(0, created);
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      _canManage
                          ? 'Đã thêm sự kiện thành công'
                          : 'Đã gửi yêu cầu phê duyệt sự kiện thành công',
                    ),
                  ),
                );
              } else {
                setState(() {
                  _currentEvents.insert(0, toCreate);
                });
              }
            }
            widget.onAddEvent?.call(newEvent);
          },
        ),
      ),
    );
  }

  // 2. Chỉnh sửa sự kiện (Admin & Editor)
  void _handleEditEvent(EventModel event) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(
          event: event,
          onEditEvent: (updatedEvent) async {
            final toUpdate = updatedEvent.copyWith(familyId: _activeFamilyId);
            final result = await EventApiService.updateEvent(toUpdate);
            if (mounted) {
              setState(() {
                final index = _currentEvents.indexWhere(
                  (e) => e.id == updatedEvent.id,
                );
                if (index != -1) {
                  _currentEvents[index] = result ?? updatedEvent;
                }
              });
              messenger.showSnackBar(
                const SnackBar(content: Text('Đã cập nhật sự kiện')),
              );
            }
            widget.onEditEvent?.call(updatedEvent);
          },
        ),
      ),
    );
  }

  // 3. Xóa sự kiện (Admin & Editor)
  void _handleDeleteEvent(EventModel event) {
    DeleteEventDialog.show(
      context,
      event: event,
      onConfirm: () async {
        final success = await EventApiService.deleteEvent(event.id);
        if (mounted) {
          setState(() {
            _currentEvents.removeWhere((e) => e.id == event.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? 'Đã xóa sự kiện' : 'Đã xóa sự kiện khỏi danh sách',
              ),
            ),
          );
        }
        widget.onDeleteEvent?.call(event.id);
      },
    );
  }

  // ==================== THÔNG BÁO & ĐỒNG BỘ ====================

  // Xử lý khi nhấn nút Sync
  Future<void> _handleSyncClick() async {
    if (_activeFamilyId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang đồng bộ sinh nhật & ngày giỗ từ cơ sở dữ liệu...')),
    );
    await _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đồng bộ xong sự kiện')),
      );
    }
  }

  // Xử lý khi nhấn vào nút chuông thông báo
  void _handleNotificationClick() {
    final upcoming = _currentEvents.take(3).toList();
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
                  'Thông báo sự kiện sắp tới',
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

            if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Không có sự kiện sắp tới', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...upcoming.map((evt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildNotificationItem(
                      title: 'Sắp diễn ra: ${evt.title}',
                      subtitle: '${evt.dateRange} • ${evt.time}',
                      time: evt.isBirthday ? 'Sinh nhật' : (evt.isDeathAnniversary ? 'Ngày giỗ' : 'Sự kiện'),
                      icon: evt.isBirthday
                          ? Icons.cake_rounded
                          : (evt.isDeathAnniversary ? Icons.temple_buddhist_rounded : Icons.notifications_active_rounded),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

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
              color: AppColors.primaryGold.withValues(alpha: 0.15),
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
}
