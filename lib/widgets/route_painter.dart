import 'package:flutter/material.dart';

class RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFE8F0E9),
    );

    final blockPaint = Paint()..color = const Color(0xFFD4E6D5);
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final minorRoad = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final blocks = [
      Rect.fromLTWH(8, 8, 90, 60),
      Rect.fromLTWH(120, 8, 75, 60),
      Rect.fromLTWH(215, 8, 90, 60),
      Rect.fromLTWH(325, 8, 60, 60),
      Rect.fromLTWH(8, 90, 90, 55),
      Rect.fromLTWH(120, 90, 75, 55),
      Rect.fromLTWH(215, 90, 90, 55),
      Rect.fromLTWH(325, 90, 60, 55),
      Rect.fromLTWH(8, 168, 90, 48),
      Rect.fromLTWH(120, 168, 75, 48),
      Rect.fromLTWH(215, 168, 90, 48),
      Rect.fromLTWH(325, 168, 60, 48),
    ];
    for (final b in blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(4)), blockPaint);
    }

    for (final y in [78.0, 155.0]) {
      canvas.drawLine(Offset(0, y), Offset(w, y), roadPaint);
    }
    for (final x in [108.0, 203.0, 313.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), roadPaint);
    }
    canvas.drawLine(const Offset(0, 4), Offset(w, 4), minorRoad);
    canvas.drawLine(Offset(0, h - 4), Offset(w, h - 4), minorRoad);

    final routePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final routePoints = [
      Offset(w * 0.18, h * 0.78),
      Offset(w * 0.18, h * 0.55),
      Offset(w * 0.35, h * 0.55),
      Offset(w * 0.35, h * 0.32),
      Offset(w * 0.55, h * 0.32),
      Offset(w * 0.55, h * 0.15),
      Offset(w * 0.72, h * 0.15),
    ];

    final path = Path()..moveTo(routePoints[0].dx, routePoints[0].dy);
    for (int i = 1; i < routePoints.length; i++) {
      path.lineTo(routePoints[i].dx, routePoints[i].dy);
    }
    canvas.drawPath(path, routePaint);

    _drawTruckIcon(canvas, routePoints[0]);
    _drawPin(canvas, routePoints.last, const Color(0xFFDC2626));
  }

  void _drawTruckIcon(Canvas canvas, Offset center) {
    canvas.drawCircle(
        center,
        22,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(center, 18, Paint()..color = Colors.white);

    final truckPaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(-2, -1), width: 22, height: 12),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, truckPaint);

    final cabin = RRect.fromRectAndRadius(
      Rect.fromLTWH(center.dx + 7, center.dy - 6, 8, 9),
      const Radius.circular(2),
    );
    canvas.drawRRect(cabin, truckPaint);

    final wheelPaint = Paint()..color = const Color(0xFF374151);
    canvas.drawCircle(center.translate(-6, 6), 3, wheelPaint);
    canvas.drawCircle(center.translate(8, 6), 3, wheelPaint);
  }

  void _drawPin(Canvas canvas, Offset tip, Color color) {
    final pinCenter = tip.translate(0, -20);

    canvas.drawCircle(
        tip,
        6,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.drawCircle(pinCenter, 14, Paint()..color = color);

    final pinPath = Path()
      ..moveTo(pinCenter.dx - 7, pinCenter.dy + 10)
      ..lineTo(pinCenter.dx, tip.dy)
      ..lineTo(pinCenter.dx + 7, pinCenter.dy + 10)
      ..close();
    canvas.drawPath(pinPath, Paint()..color = color);

    canvas.drawCircle(pinCenter, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OnTheWayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFE8F0E9));

    final blockPaint = Paint()..color = const Color(0xFFD4E6D5);
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final minorRoad = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (final b in [
      Rect.fromLTWH(0, 100, 85, 65),
      Rect.fromLTWH(110, 100, 80, 65),
      Rect.fromLTWH(215, 100, 85, 65),
      Rect.fromLTWH(325, 100, 70, 65),
      Rect.fromLTWH(0, 188, 85, 92),
      Rect.fromLTWH(110, 188, 80, 92),
      Rect.fromLTWH(215, 188, 85, 92),
      Rect.fromLTWH(325, 188, 70, 92),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(4)), blockPaint);
    }

    canvas.drawLine(Offset(0, 95), Offset(w, 95), roadPaint);
    canvas.drawLine(Offset(0, 183), Offset(w, 183), roadPaint);
    canvas.drawLine(Offset(0, h - 3), Offset(w, h - 3), minorRoad);

    for (final x in [97.0, 203.0, 313.0]) {
      canvas.drawLine(Offset(x, 80), Offset(x, h), roadPaint);
    }

    final routePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pts = [
      Offset(w * 0.22, h * 0.80),
      Offset(w * 0.22, h * 0.53),
      Offset(w * 0.42, h * 0.53),
      Offset(w * 0.42, h * 0.30),
      Offset(w * 0.68, h * 0.30),
      Offset(w * 0.68, h * 0.16),
    ];

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, routePaint);

    _drawTruck(canvas, pts[0]);
    _drawPin(canvas, pts.last, const Color(0xFF16A34A));
  }

  void _drawTruck(Canvas canvas, Offset center) {
    canvas.drawCircle(
        center,
        22,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(center, 18, Paint()..color = Colors.white);

    final p = Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: center.translate(-2, 0), width: 22, height: 11),
            const Radius.circular(2)),
        p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx + 7, center.dy - 5, 8, 8),
            const Radius.circular(2)),
        p);
    canvas.drawCircle(center.translate(-6, 6), 3, p);
    canvas.drawCircle(center.translate(8, 6), 3, p);
  }

  void _drawPin(Canvas canvas, Offset tip, Color color) {
    final c = tip.translate(0, -18);

    canvas.drawCircle(
        tip,
        5,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.drawCircle(c, 13, Paint()..color = color);

    final pinPath = Path()
      ..moveTo(c.dx - 6, c.dy + 9)
      ..lineTo(c.dx, tip.dy)
      ..lineTo(c.dx + 6, c.dy + 9)
      ..close();
    canvas.drawPath(pinPath, Paint()..color = color);
    canvas.drawCircle(c, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArrivalMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFE8F0E9));

    final blockPaint = Paint()..color = const Color(0xFFD4E6D5);
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final minorRoad = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (final b in [
      Rect.fromLTWH(0, 0, 85, 70),
      Rect.fromLTWH(110, 0, 80, 70),
      Rect.fromLTWH(215, 0, 85, 70),
      Rect.fromLTWH(325, 0, 70, 70),
      Rect.fromLTWH(0, 100, 85, 65),
      Rect.fromLTWH(110, 100, 80, 65),
      Rect.fromLTWH(215, 100, 85, 65),
      Rect.fromLTWH(325, 100, 70, 65),
      Rect.fromLTWH(0, 188, 85, 72),
      Rect.fromLTWH(110, 188, 80, 72),
      Rect.fromLTWH(215, 188, 85, 72),
      Rect.fromLTWH(325, 188, 70, 72),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(4)), blockPaint);
    }

    for (final y in [80.0, 178.0]) {
      canvas.drawLine(Offset(0, y), Offset(w, y), roadPaint);
    }
    canvas.drawLine(Offset(0, h - 3), Offset(w, h - 3), minorRoad);

    for (final x in [97.0, 203.0, 313.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), roadPaint);
    }

    final arrival = Offset(w * 0.50, h * 0.38);

    canvas.drawCircle(
        arrival, 70, Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.10));
    canvas.drawCircle(
        arrival, 50, Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.14));

    final routePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pts = [
      Offset(w * 0.24, h * 0.82),
      Offset(w * 0.24, h * 0.55),
      Offset(w * 0.42, h * 0.55),
      Offset(w * 0.42, h * 0.38),
      arrival,
    ];

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, routePaint);

    _drawTruck(canvas, pts[0]);
    _drawPin(canvas, arrival, const Color(0xFFDC2626));
  }

  void _drawTruck(Canvas canvas, Offset center) {
    canvas.drawCircle(
        center,
        22,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(center, 18, Paint()..color = Colors.white);

    final p = Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: center.translate(-2, 0), width: 22, height: 11),
            const Radius.circular(2)),
        p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx + 7, center.dy - 5, 8, 8),
            const Radius.circular(2)),
        p);
    canvas.drawCircle(center.translate(-6, 6), 3, p);
    canvas.drawCircle(center.translate(8, 6), 3, p);
  }

  void _drawPin(Canvas canvas, Offset tip, Color color) {
    final c = tip.translate(0, -18);

    canvas.drawCircle(
        tip,
        5,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.drawCircle(c, 14, Paint()..color = color);

    final pinPath = Path()
      ..moveTo(c.dx - 7, c.dy + 10)
      ..lineTo(c.dx, tip.dy)
      ..lineTo(c.dx + 7, c.dy + 10)
      ..close();
    canvas.drawPath(pinPath, Paint()..color = color);
    canvas.drawCircle(c, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
