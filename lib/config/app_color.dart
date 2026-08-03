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


  // ==========================================
  // 2. MÀU NỀN & BỀ MẶT (BACKGROUND & SURFACES)
  // ==========================================

  /// Màu nền chính (Xám kem nhạt cho background tổng thể toàn ứng dụng)
  static const Color background = Color(0xFFF8F7F5);

  /// Màu trắng (Card thành viên, Card thao tác nhanh Admin, Bottom Navigation Bar, Modal Popup Role)
  static const Color white = Colors.white;
  static const Color surface = Colors.white;

  /// Màu bề mặt kem ấm (Card tổng quan Thu/Chi/Số dư, khung thông tin cá nhân, Thẻ tổng quan Quản trị)
  static const Color surfaceWarm = Color(0xFFFFF8F0);

  /// Màu bề mặt nhạt (Input field background, ô tìm kiếm, chip chưa chọn)
  static const Color surfaceMuted = Color(0xFFF3ECE4);


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


  // ==========================================
  // 4. MÀU VIỀN & ĐƯỜNG PHÂN CÁCH (BORDER & DIVIDERS)
  // ==========================================

  /// Màu đường viền (Border card, border input field, viền nút nét đứt)
  static const Color border = Color(0xFFE5DCD3);

  /// Màu đường phân cách (Divider giữa các mục trong popup và hồ sơ)
  static const Color divider = Color(0xFFEFE6DD);

  /// Màu bóng đổ UI (Shadow 10% Opacity)
  static const Color shadow = Color(0x1A000000);


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


  // ==========================================
  // 6. MÀU TRẠNG THÁI & TÀI CHÍNH (STATUS & FINANCIAL)
  // ==========================================

  /// Màu xanh lá (Khoản Thu, thông báo thành công, nút "+ Thêm khoản thu")
  static const Color success = Color(0xFF28A745);
  static const Color income = Color(0xFF28A745);
  static const Color incomeBg = Color(0xFFE8F8EE);

  /// Màu đỏ (Khoản Chi, báo lỗi, nút Xóa, nút "+ Thêm khoản chi")
  static const Color error = Color(0xFFDC3545);
  static const Color expense = Color(0xFFDC3545);
  static const Color expenseBg = Color(0xFFFFEBEE);

  /// Màu vàng hổ phách (Quỹ Công Đức, nút "+ Thêm khoản công đức")
  static const Color donation = Color(0xFFD97706);
  static const Color donationBg = Color(0xFFFFF8E1);


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
}

/// Alias tương thích ngược
typedef AppColor = AppColors;
