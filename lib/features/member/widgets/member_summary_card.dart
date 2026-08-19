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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: const [	
          BoxShadow(	
            color: Color(0x11000000),	
            blurRadius: 6,	
            offset: Offset(0, 2),	
          ),	
        ],
      ),
      child: Row(
        children: [
          // Tổng số thành viên
          const Icon(
            Icons.people_rounded,
            size: 22,
            color: AppColors.primaryMedium,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng số thành viên',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$totalCount người',
                style: const TextStyle(
                  fontSize: 18,
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
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
