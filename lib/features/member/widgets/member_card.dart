import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/member_model.dart';

/// Widget thẻ thành viên hiển thị trong danh sách.
/// Thiết kế theo phác thảo Figma: avatar tròn + badge đời, thông tin cơ bản.
/// Hỗ trợ đổi màu cam nhận diện cho tài khoản của bản thân (isSelf).
class MemberCard extends StatelessWidget {
  final MemberModel member;
  final bool canManage;
  final bool isSelf;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  const MemberCard({
    super.key,
    required this.member,
    this.canManage = false,
    this.isSelf = false,
    this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMale = member.gender == 'Nam';
    final bool isAlive = member.status == 'Còn sống';
    final bool isMemberAdmin = member.role == 'admin' || member.role == 'owner';
    final bool isMemberEditor = member.role == 'editor';

    // Màu chủ đạo cho thẻ (Màu cam nếu là bản thân, ngược lại màu Nam/Nữ)
    final Color primaryColor = isSelf
        ? AppColors.selfPrimary
        : (isMale ? AppColors.male : AppColors.female);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelf ? AppColors.selfCardBg : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelf ? AppColors.selfCardBorder : AppColors.border,
            width: isSelf ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelf
                  ? AppColors.selfShadow
                  : AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 3),
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
                  // Tên + Badge [Bạn] + Role Badge + nút ba chấm
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.fullName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isSelf
                                      ? AppColors.selfText
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.selfPrimary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Bạn',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            if (isMemberAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.adminRoleBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.adminRoleBorder),
                                ),
                                child: const Text(
                                  'Quản trị',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.adminRoleText,
                                  ),
                                ),
                              ),
                            ] else if (isMemberEditor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.editorRoleBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.editorRoleBorder),
                                ),
                                child: const Text(
                                  'Biên tập',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.editorRoleText,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canManage) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onMoreTap,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
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
                      if (member.dateOfBirth != null) ...[
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
                      ],

                      const Spacer(),

                      // Giới tính icon + label
                      Row(
                        children: [
                          Icon(
                            isMale ? Icons.male_rounded : Icons.female_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            member.gender,
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryColor,
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
    final Color borderColor = isSelf
        ? AppColors.selfBorder
        : (isMale ? AppColors.male : AppColors.female);

    final Color bgColor = isSelf
        ? AppColors.selfBg
        : (isMale ? AppColors.maleBg : AppColors.femaleBg);

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
              color: borderColor,
              width: 2,
            ),
            color: bgColor,
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
                color: isSelf ? AppColors.selfPrimary : AppColors.primaryMedium,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowMedium,
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
    final Color iconColor = isSelf
        ? AppColors.selfPrimary
        : (isMale ? AppColors.male : AppColors.female);

    return Icon(
      Icons.person_outline_rounded,
      size: 32,
      color: iconColor,
    );
  }
}
