import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../services/admin_api_service.dart';

class EventApprovalScreen extends StatefulWidget {
  final int familyId;

  const EventApprovalScreen({super.key, required this.familyId});

  @override
  State<EventApprovalScreen> createState() => _EventApprovalScreenState();
}

class _EventApprovalScreenState extends State<EventApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<AdminEventApprovalModel> _pendingEvents = [];
  List<AdminEventApprovalModel> _approvedEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final pending = await AdminApiService.getEventsByStatus(
      familyId: widget.familyId,
      status: 'pending',
    );
    final approved = await AdminApiService.getEventsByStatus(
      familyId: widget.familyId,
      status: 'approved',
    );

    if (mounted) {
      setState(() {
        _pendingEvents = pending;
        _approvedEvents = approved;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(AdminEventApprovalModel item) async {
    final ok = await AdminApiService.approveEvent(item.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã phê duyệt sự kiện "${item.title}"'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadEvents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi khi phê duyệt sự kiện'),
          backgroundColor: AppColors.badgeRed,
        ),
      );
    }
  }

  Future<void> _handleReject(AdminEventApprovalModel item) async {
    final ok = await AdminApiService.rejectEvent(item.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã từ chối sự kiện "${item.title}"'),
          backgroundColor: AppColors.badgeRed,
        ),
      );
      _loadEvents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi khi từ chối sự kiện'),
          backgroundColor: AppColors.badgeRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Duyệt sự kiện',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: AppColors.white, size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bộ lọc sự kiện')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8DFD8), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              tabs: [
                Tab(text: 'Chờ duyệt (${_pendingEvents.length})'),
                const Tab(text: 'Đã duyệt'),
              ],
            ),
          ),

          // Content TabViews
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEventList(_pendingEvents, isPending: true),
                      _buildEventList(_approvedEvents, isPending: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(List<AdminEventApprovalModel> list, {required bool isPending}) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadEvents,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 350,
            alignment: Alignment.center,
            child: Text(
              isPending ? 'Không có sự kiện nào đang chờ duyệt' : 'Chưa có sự kiện nào đã duyệt',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: list.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildEventCard(item, isPending: isPending);
        },
      ),
    );
  }

  Widget _buildEventCard(AdminEventApprovalModel item, {required bool isPending}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F2), // Màu nền peach ấm chuẩn thiết kế
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3E7DC), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square Avatar / Image Box
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D3D1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Ảnh',
                  style: TextStyle(
                    color: Color(0xFF44403C),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Event Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Người tạo: ${item.creatorName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item.date.isNotEmpty ? item.date : '01/01/2026',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.location.isNotEmpty ? item.location : 'Nhà thờ họ',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bottom Action Row (Nếu ở tab chờ duyệt)
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Nút Từ chối
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFD6C7BC)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => _handleReject(item),
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                    label: const Text('Từ chối', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),

                // Nút Duyệt
                SizedBox(
                  height: 34,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A2E10), // Nâu đậm chuẩn Figma
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      elevation: 0,
                    ),
                    onPressed: () => _handleApprove(item),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                    label: const Text('Duyệt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
