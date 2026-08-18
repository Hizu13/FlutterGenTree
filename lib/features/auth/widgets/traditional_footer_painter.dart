import 'package:flutter/material.dart';

/// Widget vẽ phong cảnh cổng làng / đình làng cổ truyền thống Việt Nam ở chân trang.
/// Tạo cảm giác hoài cổ, trang nhã, đúng phong cách gia phả cội nguồn.
class TraditionalLandscapeFooter extends StatelessWidget {
  final double height;
  final double opacity;

  const TraditionalLandscapeFooter({
    super.key,
    this.height = 140,
    this.opacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Opacity(
          opacity: opacity,
          child: CustomPaint(
            size: Size(double.infinity, height),
            painter: _TraditionalGatePainter(),
          ),
        ),
      ),
    );
  }
}

class _TraditionalGatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Màu sắc theo tông nâu đất & vàng ấm hoài niệm
    final mountainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFD6BEA6).withValues(alpha: 0.15),
          const Color(0xFFC4A88E).withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final gatePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8D6646).withValues(alpha: 0.55),
          const Color(0xFF6B482A).withValues(alpha: 0.75),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final treePaint = Paint()
      ..color = const Color(0xFF7A5438).withValues(alpha: 0.45);

    // 1. Vẽ rặng núi mờ ảo phía xa
    final mountainPath = Path();
    mountainPath.moveTo(0, h * 0.6);
    mountainPath.quadraticBezierTo(w * 0.25, h * 0.25, w * 0.5, h * 0.5);
    mountainPath.quadraticBezierTo(w * 0.75, h * 0.3, w, h * 0.55);
    mountainPath.lineTo(w, h);
    mountainPath.lineTo(0, h);
    mountainPath.close();
    canvas.drawPath(mountainPath, mountainPaint);

    // 2. Vẽ rặng cây cổ thụ 2 bên
    _drawBanyanTree(canvas, Offset(w * 0.08, h * 0.75), 32, treePaint);
    _drawBanyanTree(canvas, Offset(w * 0.18, h * 0.8), 24, treePaint);
    _drawBanyanTree(canvas, Offset(w * 0.82, h * 0.78), 28, treePaint);
    _drawBanyanTree(canvas, Offset(w * 0.92, h * 0.72), 34, treePaint);

    // 3. Vẽ cổng Tam Quan / Mái đình làng cổ kính ở giữa
    final centerX = w * 0.5;
    final gateWidth = w * 0.46;
    final gateLeft = centerX - gateWidth / 2;
    final gateRight = centerX + gateWidth / 2;
    final gateBottom = h;

    final gatePath = Path();

    // Nền dưới cổng
    gatePath.moveTo(gateLeft - 10, gateBottom);
    gatePath.lineTo(gateLeft, h * 0.55);

    // Mái cổng trái cong vút
    gatePath.quadraticBezierTo(gateLeft - 15, h * 0.48, gateLeft + gateWidth * 0.25, h * 0.45);

    // Mái tầng 2 - Cổng chính giữa
    gatePath.lineTo(gateLeft + gateWidth * 0.28, h * 0.35);
    gatePath.quadraticBezierTo(gateLeft + gateWidth * 0.15, h * 0.28, centerX, h * 0.25);
    gatePath.quadraticBezierTo(gateRight - gateWidth * 0.15, h * 0.28, gateRight - gateWidth * 0.28, h * 0.35);

    // Mái cổng phải cong vút
    gatePath.lineTo(gateRight - gateWidth * 0.25, h * 0.45);
    gatePath.quadraticBezierTo(gateRight + 15, h * 0.48, gateRight, h * 0.55);
    gatePath.lineTo(gateRight + 10, gateBottom);

    // Cửa vòm trung tâm
    gatePath.lineTo(centerX + gateWidth * 0.16, gateBottom);
    gatePath.lineTo(centerX + gateWidth * 0.16, h * 0.68);
    gatePath.quadraticBezierTo(centerX, h * 0.58, centerX - gateWidth * 0.16, h * 0.68);
    gatePath.lineTo(centerX - gateWidth * 0.16, gateBottom);

    gatePath.close();
    canvas.drawPath(gatePath, gatePaint);

    // 4. Vẽ các cột trụ và đường nét kiến trúc cổ
    final linePaint = Paint()
      ..color = const Color(0xFFF9F3EA).withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Đường gờ mái uốn lượn
    canvas.drawLine(
      Offset(gateLeft + gateWidth * 0.28, h * 0.46),
      Offset(gateRight - gateWidth * 0.28, h * 0.46),
      linePaint,
    );
  }

  void _drawBanyanTree(Canvas canvas, Offset root, double radius, Paint paint) {
    // Tán cây vòm tròn dạng tranh thủy mặc
    canvas.drawCircle(Offset(root.dx, root.dy - radius * 0.8), radius, paint);
    canvas.drawCircle(Offset(root.dx - radius * 0.4, root.dy - radius * 0.5), radius * 0.75, paint);
    canvas.drawCircle(Offset(root.dx + radius * 0.4, root.dy - radius * 0.5), radius * 0.75, paint);

    // Thân cây
    final trunk = Path();
    trunk.moveTo(root.dx - 3, root.dy);
    trunk.lineTo(root.dx - 2, root.dy - radius * 0.6);
    trunk.lineTo(root.dx + 2, root.dy - radius * 0.6);
    trunk.lineTo(root.dx + 3, root.dy);
    trunk.close();
    canvas.drawPath(trunk, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
