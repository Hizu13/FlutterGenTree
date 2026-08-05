import 'package:flutter/material.dart';
import '../../../config/app_color.dart';

/// Widget thống kê tổng quan ở cuối màn hình danh sách thành viên.
/// Hiển thị: Tổng số thành viên | Nam (xanh) | Nữ (hồng)
class MemberSummaryCard extends StatelessWidget {
  final int totalCount;
  final int maleCount;
  final int femaleCount;

  const MemberSummaryCard({
    super.key,
    required this.totalCount,
    required this.maleCount,
    required this.femaleCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Tổng số thành viên
          const Icon(
            Icons.people_rounded,
            size: 18,
            color: AppColors.primaryMedium,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng số thành viên',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$totalCount người',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Cột Nam
          _buildGenderStat(
            label: 'Nam',
            count: maleCount,
            color: AppColors.male,
          ),
          const SizedBox(width: 20),

          // Cột Nữ
          _buildGenderStat(
            label: 'Nữ',
            count: femaleCount,
            color: AppColors.female,
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStat({
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
