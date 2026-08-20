import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/face_match_model.dart';

class MultiFacePickerSheet extends StatefulWidget {
  final List<FaceCandidate> candidates;
  final Function(FaceCandidate selected) onSelected;

  const MultiFacePickerSheet({
    super.key,
    required this.candidates,
    required this.onSelected,
  });

  @override
  State<MultiFacePickerSheet> createState() => _MultiFacePickerSheetState();
}

class _MultiFacePickerSheetState extends State<MultiFacePickerSheet> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_rounded,
                  color: AppColors.primaryGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phát hiện ${widget.candidates.length} khuôn mặt',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chạm chọn khuôn mặt bạn muốn xác thực/tìm kiếm',
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Horizontal List of Cropped Faces
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.candidates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final cand = widget.candidates[index];
                final isSelected = index == _selectedIndex;
                final base64Raw = cand.cropImageBase64.contains(',')
                    ? cand.cropImageBase64.split(',')[1]
                    : cand.cropImageBase64;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGold.withOpacity(0.1)
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGold
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: base64Raw.isNotEmpty
                              ? Image.memory(
                                  base64Decode(base64Raw),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.person),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 14,
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Người ${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSelected(widget.candidates[_selectedIndex]);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Xác nhận khuôn mặt này',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
