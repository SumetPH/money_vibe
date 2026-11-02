import 'dart:math' as math;

import 'package:flutter/material.dart';

/// โลโก้ "G" ของ Google วาดด้วย CustomPainter เพื่อไม่ต้องเพิ่ม asset/dependency
class AuthGoogleLogo extends StatelessWidget {
  final double size;
  const AuthGoogleLogo({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _GoogleLogoPainter()),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  // design-check: allow Google brand color
  static const _blue = Color(0xFF4285F4);
  // design-check: allow Google brand color
  static const _green = Color(0xFF34A853);
  // design-check: allow Google brand color
  static const _yellow = Color(0xFFFBBC05);
  // design-check: allow Google brand color
  static const _red = Color(0xFFEA4335);

  const _GoogleLogoPainter();

  double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(
      center: center,
      radius: (size.width - stroke) / 2,
    );
    Paint paintFor(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // องศาเริ่มที่ 3 นาฬิกาและเดินตามเข็ม: น้ำเงิน → เขียว → เหลือง → แดง
    canvas
      ..drawArc(rect, _rad(0), _rad(45), false, paintFor(_blue))
      ..drawArc(rect, _rad(45), _rad(100), false, paintFor(_green))
      ..drawArc(rect, _rad(145), _rad(70), false, paintFor(_yellow))
      ..drawArc(rect, _rad(215), _rad(100), false, paintFor(_red))
      ..drawRect(
        Rect.fromLTRB(
          center.dx,
          center.dy - stroke / 2,
          size.width,
          center.dy + stroke / 2,
        ),
        Paint()..color = _blue,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
