import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/event_model.dart';

/// Callback function types cho popup menu actions
typedef OnViewEvent = void Function(EventModel event);
typedef OnEditEvent = void Function(EventModel event);
typedef OnDeleteEvent = void Function(EventModel event);
typedef OnApproveEvent = void Function(EventModel event);
typedef OnRejectEvent = void Function(EventModel event);

/// Widget hiển thị popup menu cho sự kiện
class EventPopupMenu extends StatelessWidget {
  final EventModel event;
  final OnViewEvent? onView;
  final OnEditEvent? onEdit;
  final OnDeleteEvent? onDelete;
  final OnApproveEvent? onApprove;
  final OnRejectEvent? onReject;

  const EventPopupMenu({
    super.key,
    required this.event,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onSelected: (value) => _handleMenuAction(context, value),
      itemBuilder: (BuildContext context) => _buildMenuItems(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    return [
      PopupMenuItem<String>(
        value: 'edit',
        enabled: onEdit != null,
        child: _MenuItemWidget(
          icon: Icons.edit_outlined,
          label: 'Chỉnh sửa',
          enabled: onEdit != null,
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        enabled: onDelete != null,
        child: _MenuItemWidget(
          icon: Icons.delete_outline,
          label: 'Xóa',
          color: AppColors.error,
          enabled: onDelete != null,
        ),
      ),
    ];
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        onEdit?.call(event);
        break;
      case 'delete':
        onDelete?.call(event);
        break;
    }
  }
}

/// Widget item menu custom
class _MenuItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;

  const _MenuItemWidget({
    required this.icon,
    required this.label,
    this.color = AppColors.textPrimary,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: enabled ? color : AppColors.textMuted),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: enabled ? color : AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
