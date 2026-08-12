import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';

class FinanceSummaryCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;

  const FinanceSummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
  });

  double get balance => totalIncome - totalExpense;

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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildItem(
              'Tổng thu',
              _formatCurrency(totalIncome),
              AppColors.income,
            ),
          ),
          _buildDivider(), // Nét dọc phân cách 1
          Expanded(
            child: _buildItem(
              'Tổng chi',
              _formatCurrency(totalExpense),
              AppColors.expense,
            ),
          ),
          _buildDivider(), // Nét dọc phân cách 2
          Expanded(
            child: _buildItem(
              'Số dư',
              _formatCurrency(balance),
              AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Widget tạo đường gạch dọc ngắn
  Widget _buildDivider() {
    return Container(
      height: 24, // Độ cao của đường vạch dọc
      width: 1, // Độ dày của đường vạch
      color: AppColors.border, // Màu sắc của đường vạch
    );
  }

  Widget _buildItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Căn giữa nội dung
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
