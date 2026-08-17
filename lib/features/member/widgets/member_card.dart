import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/member_model.dart';

/// Widget thẻ thành viên hiển thị trong danh sách.
/// Thiết kế theo phác thảo Figma: avatar tròn + badge đời, thông tin cơ bản.
class MemberCard extends StatelessWidget {
  final MemberModel member;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  const MemberCard({
    super.key,
    required this.member,
    this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMale = member.gender == 'Nam';
    final bool isAlive = member.status == 'Còn sống';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ──────────────────────────────────────────────────
            _buildAvatarWithBadge(isMale),

            const SizedBox(width: 14),

            // ── Thông tin thành viên ────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  // Tên + nút ba chấm
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          member.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onMoreTap,
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Hàng 1: Địa chỉ + Số điện thoại
                  Row(
                    children: [
                      // Địa chỉ
                      if (member.currentAddress != null || member.placeOfBirth != null)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  member.currentAddress ?? member.placeOfBirth ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Số điện thoại
                      if (member.phoneNumber != null) ...[
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              member.phoneNumber!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Hàng 2: Ngày sinh + Giới tính
                  Row(
                    children: [
                      // Ngày sinh
                      if (member.dateOfBirth != null)                       
                            const Icon(
                              Icons.cake_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              member.dateOfBirth!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                     

                      const Spacer(),

                      // Giới tính icon + label
                      Row(
                        children: [
                          Icon(
                            isMale ? Icons.male_rounded : Icons.female_rounded,
                            size: 16,
                            color: isMale ? AppColors.male : AppColors.female,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            member.gender,
                            style: TextStyle(
                              fontSize: 13,
                              color: isMale ? AppColors.male : AppColors.female,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Trạng thái "Đã mất" (chỉ hiện nếu đã mất)
                  if (!isAlive) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Đã mất',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWithBadge(bool isMale) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Avatar tròn
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isMale ? AppColors.male : AppColors.female,
              width: 2,
            ),
            color: isMale ? AppColors.maleBg : AppColors.femaleBg,
          ),
          child: ClipOval(
            child: member.resolvedAvatarUrl != null && member.resolvedAvatarUrl!.isNotEmpty
                ? Image.network(
                    member.resolvedAvatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _buildDefaultAvatar(isMale),
                  )
                : _buildDefaultAvatar(isMale),
          ),
        ),

        // Badge Đời (phía dưới trái avatar)
        if (member.generation != null)
          Positioned(
            bottom: -6,
            left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryMedium,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Đời ${member.generation}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar(bool isMale) {
    return Icon(
      isMale ? Icons.person_outline_rounded : Icons.person_outline_rounded,
      size: 32,
      color: isMale ? AppColors.male : AppColors.female,
    );
  }
}
