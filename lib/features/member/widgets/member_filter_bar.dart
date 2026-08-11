import 'package:flutter/material.dart';
import '../../../config/app_color.dart';

/// Widget thanh bộ lọc cho danh sách thành viên.
/// Gồm: chips lọc theo Đời, Giới tính, Địa chỉ, và nút Sắp xếp.
class MemberFilterBar extends StatefulWidget {
  final int totalCount;
  final String? selectedGeneration; // null = Tất cả
  final String? selectedGender;     // null = Tất cả, 'Nam', 'Nữ'
  final String? selectedAddress;    // null = Tất cả
  final String sortLabel;
  final List<String> generationOptions;
  final List<String> addressOptions;
  final ValueChanged<String?> onGenerationChanged;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onAddressChanged;
  final VoidCallback onSortTap;

  const MemberFilterBar({
    super.key,
    required this.totalCount,
    this.selectedGeneration,
    this.selectedGender,
    this.selectedAddress,
    this.sortLabel = 'Sắp xếp',
    this.generationOptions = const [],
    this.addressOptions = const [],
    required this.onGenerationChanged,
    required this.onGenderChanged,
    required this.onAddressChanged,
    required this.onSortTap,
  });

  @override
  State<MemberFilterBar> createState() => _MemberFilterBarState();
}

class _MemberFilterBarState extends State<MemberFilterBar> {
  String? _openDropdown; // 'generation' | 'gender' | 'address' | null

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ── Chip Tất cả (tổng số) ─────────────────────
            _buildAllChip(),
            const SizedBox(width: 8),

            // ── Dropdown Đời ─────────────────────────────
            _buildDropdownChip(
              label: widget.selectedGeneration ?? 'Đời',
              isActive: widget.selectedGeneration != null,
              dropdownKey: 'generation',
              options: widget.generationOptions,
              onSelected: (val) {
                setState(() => _openDropdown = null);
                widget.onGenerationChanged(val);
              },
            ),
            const SizedBox(width: 8),

            // ── Dropdown Giới tính ───────────────────────
            _buildDropdownChip(
              label: widget.selectedGender ?? 'Giới tính',
              isActive: widget.selectedGender != null,
              dropdownKey: 'gender',
              options: const ['Nam', 'Nữ'],
              onSelected: (val) {
                setState(() => _openDropdown = null);
                widget.onGenderChanged(val);
              },
            ),
            const SizedBox(width: 8),

            // ── Dropdown Địa chỉ ─────────────────────────
            _buildDropdownChip(
              label: widget.selectedAddress ?? 'Địa chỉ',
              isActive: widget.selectedAddress != null,
              dropdownKey: 'address',
              options: widget.addressOptions,
              onSelected: (val) {
                setState(() => _openDropdown = null);
                widget.onAddressChanged(val);
              },
            ),
            const SizedBox(width: 8),

            // ── Nút Sắp xếp ─────────────────────────────
            _buildSortChip(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllChip() {
    return GestureDetector(
      onTap: () {
        setState(() => _openDropdown = null);
        widget.onGenerationChanged(null);
        widget.onGenderChanged(null);
        widget.onAddressChanged(null);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryMedium,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Tất cả (${widget.totalCount})',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required bool isActive,
    required String dropdownKey,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    final bool isOpen = _openDropdown == dropdownKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _openDropdown = isOpen ? null : dropdownKey;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? AppColors.surfaceWarm : AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? AppColors.primaryMedium : AppColors.border,
                width: isActive ? 1.2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? AppColors.primaryMedium : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: isActive ? AppColors.primaryMedium : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),

        // Dropdown menu dạng inline (chỉ render khi mở)
        if (isOpen && options.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: options.map((opt) {
                final bool selected = (dropdownKey == 'generation' && widget.selectedGeneration == opt) ||
                    (dropdownKey == 'gender' && widget.selectedGender == opt) ||
                    (dropdownKey == 'address' && widget.selectedAddress == opt);
                return GestureDetector(
                  onTap: () => onSelected(selected ? null : opt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: selected ? AppColors.surfaceWarm : Colors.transparent,
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: selected ? AppColors.primaryMedium : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSortChip() {
    return GestureDetector(
      onTap: () {
        setState(() => _openDropdown = null);
        widget.onSortTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              widget.sortLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
