import 'package:flutter/material.dart';
//update to develop
/// Class `AppColors` định nghĩa toàn bộ bảng màu (Color Palette) của ứng dụng

class AppColors {
  AppColors._();

  // ==========================================
  // 1. MÀU CHỦ ĐẠO & THƯƠNG HIỆU (PRIMARY & BRAND)
  // ==========================================

  /// Màu nâu đậm chủ đạo (Header AppBar màn hình Trang chủ, Danh sách, Hồ sơ, Thêm thành viên & Quản trị)
  static const Color primary = Color(0xFF6B3E1E);
  static const Color primaryDark = Color(0xFF6B3E1E);

  /// Màu vàng chủ đạo (Nút FAB +, nút áp dụng bộ lọc, icon checkmark xác thực AI)
  static const Color primaryGold = Color(0xFFC68A1E);

  /// Màu nâu hạt dẻ (Badge Đời thành viên, nút bộ lọc chọn đời, nút "Mở Camera AI")
  static const Color primaryMedium = Color(0xFF8D4B20);

  /// Màu vàng kem nhạt (Highlight tab lựa chọn bộ lọc thế hệ trong sơ đồ gia phả)
  static const Color primaryLightGold = Color(0xFFE5B869);

  /// Màu nâu gỗ sẫm đặc biệt (Header màn hình chào mừng Welcome, Top Banner)
  static const Color primaryExtraDark = Color(0xFF5A3113);

  /// Màu nâu sẫm đậm nét (Tiêu đề chữ lớn trên nền sáng)
  static const Color primaryDeep = Color(0xFF3B200E);

  /// Màu nâu cổ điển (Sử dụng trong form gia phả truyền thống)
  static const Color brownOld = Color(0xFF603813);
  static const Color brownOldLight = Color(0xFF7A4B1B);

  /// Màu vàng kem ấm (Màu điểm xuyết, nút bấm nhẹ)
  static const Color goldMedium = Color(0xFFD4A373);

  // ==========================================
  // 2. MÀU NỀN & BỀ MẶT (BACKGROUND & SURFACES)
  // ==========================================

  /// Màu nền chính (Xám kem nhạt cho background tổng thể toàn ứng dụng)
  static const Color background = Color(0xFFF8F7F5);
  static const Color backgroundScaffold = Color(0xFFF9F7F3);
  static const Color scaffoldBg = Color(0xFFF9F7F2);

  /// Màu trắng (Card thành viên, Card thao tác nhanh Admin, Bottom Navigation Bar, Modal Popup Role)
  static const Color white = Colors.white;
  static const Color surface = Colors.white;

  /// Màu bề mặt kem ấm (Card tổng quan Thu/Chi/Số dư, khung thông tin cá nhân, Thẻ tổng quan Quản trị)
  static const Color surfaceWarm = Color(0xFFFFF8F0);
  static const Color surfaceWarmLight = Color(0xFFFFF7EE);

  /// Màu bề mặt nhạt (Input field background, ô tìm kiếm, chip chưa chọn)
  static const Color surfaceMuted = Color(0xFFF3ECE4);
  static const Color inputBg = Color(0xFFF5F3EF);

  /// Màu bề mặt thẻ phụ / Card nền sáng
  static const Color surfaceCardLight = Color(0xFFFAF7F2);
  static const Color surfaceCardWarm = Color(0xFFFAF6F0);
  static const Color surfaceCardWarmAlt = Color(0xFFFAF3EC);
  static const Color surfaceGoldLight = Color(0xFFFAF2E6);

  // ==========================================
  // 3. MÀU CHỮ & NỘI DUNG (TYPOGRAPHY & CONTENT)
  // ==========================================

  /// Màu đen nâu (Chữ tiêu đề chính, Tên thành viên, Giá trị số dư, Tiêu đề mục quản trị)
  static const Color textPrimary = Color(0xFF2D1C10);

  /// Màu xám nâu (Chữ phụ: Địa chỉ, Số điện thoại, CCCD, Ngày sinh, Subtitle số yêu cầu chờ duyệt)
  static const Color textSecondary = Color(0xFF7D6E65);

  /// Màu xám mờ (Chữ gợi ý placeholder ô tìm kiếm, icon chevron mũi tên)
  static const Color textMuted = Color(0xFFA3968C);

  /// Màu chữ trắng (Hiển thị trên nền nâu đậm AppBar hoặc nút bấm chính)
  static const Color textLight = Colors.white;

  /// Màu nâu mờ (Chữ ghi chú thông tin)
  static const Color textBrownMuted = Color(0xFF8C7A6B);

  /// Màu xám đậm
  static const Color textDarkGray = Color(0xFF4A4A4A);

  // ==========================================
  // 4. MÀU VIỀN & ĐƯỜNG PHÂN CÁCH (BORDER & DIVIDERS)
  // ==========================================

  /// Màu đường viền chuẩn (Border card, border input field, viền nút nét đứt)
  static const Color border = Color(0xFFE5DCD3);

  /// Màu đường phân cách (Divider giữa các mục trong popup và hồ sơ)
  static const Color divider = Color(0xFFEFE6DD);

  /// Màu bóng đổ UI (Shadow 10% Opacity)
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x10000000);
  static const Color shadowMedium = Color(0x22000000);

  /// Màu viền nhạt
  static const Color borderLight = Color(0xFFF0EAE1);
  static const Color borderWarm = Color(0xFFEBE2D5);
  static const Color borderMuted = Color(0xFFDDD2C4);
  static const Color borderColor = Color(0xFFE8E2D8);
  static const Color borderCard = Color(0xFFF0E4D7);

  // ==========================================
  // 5. MÀU GIỚI TÍNH & GIA PHẢ (GENDER & TREE)
  // ==========================================

  /// Màu xanh dương chỉ báo Nam (Thống kê Nam, viền node Nam trong sơ đồ gia phả)
  static const Color male = Color(0xFF00A8E8);
  static const Color maleBg = Color(0xFFE6F7FF);

  /// Màu hồng chỉ báo Nữ (Thống kê Nữ, viền node Nữ trong sơ đồ gia phả)
  static const Color female = Color(0xFFFF5C8D);
  static const Color femaleBg = Color(0xFFFFF0F5);

  /// Màu cam nổi bật chỉ báo "Bản thân" trong sơ đồ gia phả
  static const Color selfNode = Color(0xFFF57C00);

  /// Màu đỏ trái tim kết nối hôn nhân Vợ/Chồng
  static const Color marriageHeart = Color(0xFFE53935);

  /// Màu nâu đậm kết nối các nhánh trong cây gia phả
  static const Color treeLine = Color(0xFF4A3B32);

  /// Màu xanh lá nổi bật viền node
  static const Color treeHighlightGreen = Color(0xFF00FF00);

  // ==========================================
  // 6. MÀU TRẠNG THÁI & TÀI CHÍNH (STATUS & FINANCIAL)
  // ==========================================

  /// Màu xanh lá (Khoản Thu, thông báo thành công, nút "+ Thêm khoản thu")
  static const Color success = Color(0xFF28A745);
  static const Color successDark = Color(0xFF2E7D32);
  static const Color income = Color(0xFF28A745);
  static const Color incomeDark = Color(0xFF2E7D32);
  static const Color incomeBg = Color(0xFFE8F8EE);
  static const Color incomeBgAlt = Color(0xFFE8F5E9);

  /// Màu đỏ (Khoản Chi, báo lỗi, nút Xóa, nút "+ Thêm khoản chi")
  static const Color error = Color(0xFFDC3545);
  static const Color expense = Color(0xFFDC3545);
  static const Color expenseBg = Color(0xFFFFEBEE);
  static const Color expenseDark = Color(0xFFD32F2F);
  static const Color expenseRed = Color(0xFFDE3B40);

  /// Màu vàng hổ phách (Quỹ Công Đức, nút "+ Thêm khoản công đức")
  static const Color donation = Color(0xFFD97706);
  static const Color donationBg = Color(0xFFFFF8E1);
  static const Color donationDark = Color(0xFFF57F17);

  // ==========================================
  // 7. MÀU QUẢN TRỊ & BÁO ĐỘNG (ADMIN & BADGES)
  // ==========================================

  /// Badge đỏ thông báo (Số lượng chờ duyệt "5", nút Đăng xuất chữ đỏ trong Popup Role)
  static const Color badgeRed = Color(0xFFE53935);
  static const Color badgeRedBg = Color(0xFFFFEBEE);

  /// Trạng thái Chờ duyệt / Cảnh báo (Thẻ "5 Chờ duyệt" trong Dashboard Quản trị)
  static const Color warning = Color(0xFFF57C00);
  static const Color warningBg = Color(0xFFFFF3E0);

  /// Trạng thái Thông tin / Tổng quan (Thẻ "123 Tổng thành viên")
  static const Color info = Color(0xFF00A8E8);
  static const Color infoBg = Color(0xFFE6F7FF);

  /// Thẻ ngày tháng sự kiện (Khung "24 Tháng 05 2024" trong Sự kiện sắp tới)
  static const Color dateBadge = Color(0xFF6B3E1E);

  // ==========================================
  // 8. GRADIENTS MÀU SẮC (GRADIENTS)
  // ==========================================

  /// Gradient Nâu chủ đạo (Header AppBar)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6B3E1E), Color(0xFF8D4B20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient Nâu cổ điển (Genealogy Form Header)
  static const LinearGradient brownGradient = LinearGradient(
    colors: [Color(0xFF603813), Color(0xFF7A4B1B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient Vàng đồng (Nút bấm nổi bật)
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFC68A1E), Color(0xFFE5B869)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient Khoản Thu (Xanh lá)
  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF28A745), Color(0xFF34C759)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient Khoản Chi (Đỏ)
  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFDC3545), Color(0xFFFF3B30)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===========================================================================
  // 9. MÀU BẢN THÂN (SELF IDENTITY - ORANGE THEME)
  // ===========================================================================

  /// Màu cam đậm chủ đạo nhận diện Bản thân người dùng đang đăng nhập
  static const Color selfPrimary = Color(0xFFEA580C);

  /// Màu cam sáng làm viền Avatar và viền Badge [Bạn]
  static const Color selfBorder = Color(0xFFF97316);

  /// Màu cam nền nhạt ấm áp cho Avatar bản thân
  static const Color selfBg = Color(0xFFFFF3E0);

  /// Màu nền thẻ Card của bản thân (ấm và sáng hơn card thường)
  static const Color selfCardBg = Color(0xFFFFFBF6);

  /// Màu viền thẻ Card của bản thân
  static const Color selfCardBorder = Color(0xFFFDBA74);

  /// Màu chữ tên của bản thân
  static const Color selfText = Color(0xFF9A3412);

  /// Màu bóng đổ nhẹ màu cam của thẻ bản thân
  static const Color selfShadow = Color(0x1AEA580C);

  // ===========================================================================
  // 10. MÀU VAI TRÒ (ROLES: ADMIN / EDITOR / MEMBER)
  // ===========================================================================

  /// Màu chữ & viền Quản trị (Admin/Owner)
  static const Color adminRoleText = Color(0xFF6B3E1E);
  static const Color adminRoleBg = Color(0xFFF3E7DC);
  static const Color adminRoleBorder = Color(0xFFD4B89C);

  /// Màu chữ & viền Biên tập viên (Editor)
  static const Color editorRoleText = Color(0xFF1E60B5);
  static const Color editorRoleBg = Color(0xFFE8F1FF);
  static const Color editorRoleBorder = Color(0xFFB5D3FF);
  static const Color primaryBlue = Color(0xFF1E60B5);
}

/// Class `AppTextStyles` chuẩn hóa Typography và kích cỡ phông chữ toàn ứng dụng
class AppTextStyles {
  AppTextStyles._();

  /// Tiêu đề màn hình lớn (AppBar, Welcome Title) - 20px / Bold
  static const TextStyle h1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Tiêu đề phân mục chính (Section Card Title) - 18px / Bold
  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Tiêu đề thẻ thành viên, mục danh sách - 16px / ExtraBold
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// Tiêu đề phụ, nút bấm chính - 15px / SemiBold
  static const TextStyle title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Chữ nội dung tiêu chuẩn - 14px / Regular
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  /// Chữ nội dung phụ - 13px / Regular
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  /// Label các trường nhập liệu - 12px / SemiBold
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Chữ gợi ý Placeholder - 12.5px / Regular
  static const TextStyle hint = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  /// Chữ chú thích nhỏ (Badge, Đời, Thời gian) - 10px / Bold
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: AppColors.textSecondary,
  );
}

/// Alias tương thích ngược
typedef AppColor = AppColors;
