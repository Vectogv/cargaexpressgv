import 'package:flutter/material.dart';

class ConfirmarEntregaScreen extends StatelessWidget {
  final VoidCallback onConfirmar;
  final VoidCallback onReportar;

  const ConfirmarEntregaScreen({
    super.key,
    required this.onConfirmar,
    required this.onReportar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _Illustration(),
              const SizedBox(height: 36),
              const Text(
                '\u00bfTodo est\u00e1 en orden?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Si la carga fue entregada correctamente,\nconfirma para finalizar el viaje.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onConfirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'S\u00ed, confirmar entrega',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onReportar,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reportar un problema',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF97316),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 180,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            left: 30,
            child: CustomPaint(
              size: const Size(120, 150),
              painter: _ClipboardPainter(),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 18,
            child: CustomPaint(
              size: const Size(70, 65),
              painter: _BoxPainter(),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 18,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3322C55E),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 26,
                weight: 700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boardPaint = Paint()..color = const Color(0xFFF9FAFB);
    final borderPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final clipPaint = Paint()..color = const Color(0xFFD1D5DB);
    final linePaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final checkLinePaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 14, size.width, size.height - 14),
      const Radius.circular(10),
    );
    canvas.drawRRect(body, boardPaint);
    canvas.drawRRect(body, borderPaint);

    final clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.3, 6, size.width * 0.4, 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(clip, clipPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.38, 0, size.width * 0.24, 14),
        const Radius.circular(7),
      ),
      Paint()
        ..color = const Color(0xFF9CA3AF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final lineY = [50.0, 68.0, 86.0, 104.0];
    final lineWidths = [0.7, 0.55, 0.65, 0.45];
    for (var i = 0; i < lineY.length; i++) {
      canvas.drawLine(
        Offset(16, lineY[i]),
        Offset(size.width * lineWidths[i] + 16, lineY[i]),
        linePaint,
      );
    }

    canvas.drawLine(
      Offset(16, 122),
      Offset(size.width * 0.5, 122),
      checkLinePaint,
    );

    final checkPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(size.width * 0.62, 118)
      ..lineTo(size.width * 0.68, 126)
      ..lineTo(size.width * 0.8, 114);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frontPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.7),
        const Radius.circular(4),
      ),
      frontPaint,
    );

    final topPaint = Paint()..color = const Color(0xFFD97706);
    final topPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width * 0.15, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(size.width, size.height * 0.3)
      ..close();
    canvas.drawPath(topPath, topPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFC2590A).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, size.height * 0.3 + (size.height * 0.7) / 2),
      Offset(size.width, size.height * 0.3 + (size.height * 0.7) / 2),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.3),
      Offset(size.width / 2, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height * 0.3),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
