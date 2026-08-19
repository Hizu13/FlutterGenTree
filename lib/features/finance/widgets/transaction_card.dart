import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../models/transaction_model.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.canManage = false,
    this.onTap,
    this.onApprove,
    this.onReject,
    this.onDelete,
  });

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
    Color iconBg;
    Color iconColor;
    IconData iconData;
    String prefix = '';
    Color amountColor;

    switch (transaction.type) {
      case TransactionType.income:
        iconBg = AppColors.incomeBg;
        iconColor = AppColors.income;
        iconData = Icons.card_giftcard;
        prefix = '+';
        amountColor = AppColors.income;
        break;
      case TransactionType.expense:
        iconBg = AppColors.expenseBg;
        iconColor = AppColors.expense;
        iconData = Icons.shopping_basket_outlined;
        prefix = '-';
        amountColor = AppColors.expense;
        break;
      case TransactionType.merit:
        iconBg = AppColors.donationBg;
        iconColor = AppColors.donation;
        iconData = Icons.spa_outlined;
        prefix = '+';
        amountColor = AppColors.donation;
        break;
      default:
        iconBg = AppColors.surfaceMuted;
        iconColor = AppColors.primary;
        iconData = Icons.receipt;
        amountColor = AppColors.textPrimary;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Icon hình tròn bên trái
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Thông tin tiêu đề & Tên người đóng/chi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (transaction.isPending) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                          ),
                          child: const Text(
                            'Chờ duyệt',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ] else if (transaction.isRejected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE57373), width: 0.8),
                          ),
                          child: const Text(
                            'Từ chối',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.badgeRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.personName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Số tiền & Loại danh mục
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$prefix${_formatCurrency(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),

            // Menu tùy chọn (Admin / Editor)
            if (canManage && (onApprove != null || onReject != null || onDelete != null))
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                onSelected: (value) {
                  if (value == 'approve' && onApprove != null) onApprove!();
                  if (value == 'reject' && onReject != null) onReject!();
                  if (value == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (ctx) => [
                  if (transaction.isPending && onApprove != null)
                    const PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text('Phê duyệt', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (transaction.isPending && onReject != null)
                    const PopupMenuItem(
                      value: 'reject',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: AppColors.badgeRed, size: 18),
                          SizedBox(width: 8),
                          Text('Từ chối', style: TextStyle(color: AppColors.badgeRed)),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.badgeRed, size: 18),
                          SizedBox(width: 8),
                          Text('Xóa giao dịch', style: TextStyle(color: AppColors.badgeRed)),
                        ],
                      ),
                    ),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
