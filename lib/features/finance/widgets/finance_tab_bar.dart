import 'package:flutter/material.dart';
import 'package:gentree/config/app_color.dart';

class FinanceTabBar extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int>? onTap;

  const FinanceTabBar({super.key, required this.controller, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        onTap: onTap,
        indicator: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Tất cả'),
          Tab(text: 'Thu'),
          Tab(text: 'Chi'),
          Tab(text: 'Công đức'),
        ],
      ),
    );
  }
}
