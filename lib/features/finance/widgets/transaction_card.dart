import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';
import '../models/transaction_model.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

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
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 4),
            const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
