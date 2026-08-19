import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../../event/services/event_api_service.dart';
import '../../finance/services/finance_api_service.dart';
import '../services/admin_api_service.dart';

class ApprovalListScreen extends StatefulWidget {
  final int familyId;

  const ApprovalListScreen({super.key, required this.familyId});

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen> {
  bool _isLoading = false;
  List<PendingItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await AdminApiService.getPendingItems(widget.familyId);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(PendingItemModel item) async {
    bool ok = false;
    if (item.category == 'finance') {
      ok = await FinanceApiService.approveTransaction(item.id.toString());
    } else if (item.category == 'event') {
      ok = await EventApiService.approveEvent(item.id.toString());
    }

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã phê duyệt yêu cầu thành công!'), backgroundColor: AppColors.success),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể phê duyệt yêu cầu'), backgroundColor: AppColors.badgeRed),
        );
      }
    }
  }

  Future<void> _handleReject(PendingItemModel item) async {
    bool ok = false;
    if (item.category == 'finance') {
      ok = await FinanceApiService.rejectTransaction(item.id.toString());
    } else if (item.category == 'event') {
      ok = await EventApiService.rejectEvent(item.id.toString());
    }

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối yêu cầu'), backgroundColor: AppColors.badgeRed),
        );
        _loadData();
      }
    }
  }

  String _formatCurrency(double amount) {
    final String priceStr = amount.abs().toStringAsFixed(0);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final String formatted = priceStr.replaceAllMapped(
      reg,
      (Match m) => '${m[1]}.',
    );
    return '$formatted đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'Duyệt yêu cầu',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'Hiện không có yêu cầu nào chờ duyệt',
                        style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isFinance = item.category == 'finance';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x08000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isFinance ? AppColors.incomeBg : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isFinance ? 'Thu chi (${item.type})' : 'Sự kiện',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isFinance ? AppColors.income : const Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (item.date.isNotEmpty)
                                  Text(
                                    item.date,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (isFinance && item.amount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Số tiền: ${_formatCurrency(item.amount)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ],
                            if (item.personName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Người đề xuất: ${item.personName}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Ghi chú: ${item.note}',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.badgeRed,
                                      side: const BorderSide(color: AppColors.badgeRed),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _handleReject(item),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Từ chối'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _handleApprove(item),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Phê duyệt'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
