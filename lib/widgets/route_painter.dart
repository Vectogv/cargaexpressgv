import 'package:flutter/material.dart';

class ConfirmationIllustrationPainter extends CustomPainter {
  static const Color _blue = Color(0xFF2563EB);
  static const Color _lightBlue = Color(0xFFBFDBFE);
  static const Color _paleBlue = Color(0xFFEFF6FF);
  static const Color _boxBlue = Color(0xFF93C5FD);
  static const Color _boxDark = Color(0xFF60A5FA);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(Offset(cx, cy), 72, Paint()..color = _paleBlue);

    final dotPaint = Paint()..color = _lightBlue;
    final dots = [
      Offset(cx - 58, cy - 40),
      Offset(cx + 55, cy - 45),
      Offset(cx - 62, cy + 20),
      Offset(cx + 60, cy + 15),
      Offset(cx - 30, cy - 62),
      Offset(cx + 28, cy - 64),
      Offset(cx - 10, cy + 65),
    ];
    for (final d in dots) {
      canvas.drawCircle(d, 4, dotPaint);
    }

    final boxLeft = cx - 52.0;
    final boxTop = cy + 4.0;
    final boxW = 70.0;
    final boxH = 48.0;

    final lidPath = Path()
      ..moveTo(boxLeft, boxTop)
      ..lineTo(boxLeft + boxW, boxTop)
      ..lineTo(boxLeft + boxW + 10, boxTop - 12)
      ..lineTo(boxLeft + 10, boxTop - 12)
      ..close();
    canvas.drawPath(lidPath, Paint()..color = _boxBlue);

    canvas.drawRect(Rect.fromLTWH(boxLeft, boxTop, boxW, boxH), Paint()..color = _boxDark);

    final sidePath = Path()
      ..moveTo(boxLeft + boxW, boxTop)
      ..lineTo(boxLeft + boxW + 10, boxTop - 12)
      ..lineTo(boxLeft + boxW + 10, boxTop - 12 + boxH)
      ..lineTo(boxLeft + boxW, boxTop + boxH)
      ..close();
    canvas.drawPath(sidePath, Paint()..color = _boxBlue);

    canvas.drawLine(
      Offset(boxLeft + boxW / 2, boxTop - 12),
      Offset(boxLeft + boxW / 2 + 5, boxTop),
      Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(boxLeft + boxW / 2 + 5, boxTop),
      Offset(boxLeft + boxW / 2 + 5, boxTop + boxH),
      Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = 1.5,
    );

    final clockCenter = Offset(cx + 22, cy - 18);
    const clockR = 36.0;

    canvas.drawCircle(
        clockCenter, clockR + 2,
        Paint()..color = _blue.withValues(alpha: 0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.drawCircle(clockCenter, clockR, Paint()..color = Colors.white);
    canvas.drawCircle(clockCenter, clockR, Paint()..color = _lightBlue..style = PaintingStyle.stroke..strokeWidth = 2.5);

    final markPaint = Paint()..color = _lightBlue..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final angle = i * 30 * 3.14159 / 180;
      final inner = i % 3 == 0 ? clockR - 9 : clockR - 6;
      canvas.drawLine(
        Offset(clockCenter.dx + inner * _sin(angle), clockCenter.dy - inner * _cos(angle)),
        Offset(clockCenter.dx + (clockR - 3) * _sin(angle), clockCenter.dy - (clockR - 3) * _cos(angle)),
        markPaint,
      );
    }

    final hourAngle = -60 * 3.14159 / 180;
    canvas.drawLine(
      clockCenter,
      Offset(clockCenter.dx + 18 * _sin(hourAngle), clockCenter.dy - 18 * _cos(hourAngle)),
      Paint()..color = _blue..strokeWidth = 3..strokeCap = StrokeCap.round,
    );

    const minAngle = 0.0;
    canvas.drawLine(
      clockCenter,
      Offset(clockCenter.dx + 26 * _sin(minAngle), clockCenter.dy - 26 * _cos(minAngle)),
      Paint()..color = _blue..strokeWidth = 2.5..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(clockCenter, 3.5, Paint()..color = _blue);
  }

  double _sin(double rad) => _mathSin(rad);
  double _cos(double rad) => _mathCos(rad);

  static double _mathSin(double x) {
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _mathCos(double x) {
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
