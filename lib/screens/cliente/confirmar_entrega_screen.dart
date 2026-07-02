import 'package:flutter/material.dart';

class ConfirmarEntregaScreen extends StatefulWidget {
  final VoidCallback onConfirmar;
  final VoidCallback onReportar;

  const ConfirmarEntregaScreen({
    super.key,
    required this.onConfirmar,
    required this.onReportar,
  });

  @override
  State<ConfirmarEntregaScreen> createState() => _ConfirmarEntregaScreenState();
}

class _ConfirmarEntregaScreenState extends State<ConfirmarEntregaScreen> {
  bool _loading = false;

  Future<void> _handleConfirmar() async {
    if (_loading) return;
    setState(() => _loading = true);
    widget.onConfirmar();
  }

  Future<void> _handleReportar() async {
    if (_loading) return;
    setState(() => _loading = true);
    widget.onReportar();
  }

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
              const _Illustration(),
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
                  onPressed: _loading ? null : _handleConfirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text(
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
                  onPressed: _loading ? null : _handleReportar,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF97316)))
                      : const Text(
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
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 180,
      child: CustomPaint(
        painter: _DeliveryPainter(),
        size: const Size(200, 180),
      ),
    );
  }
}

class _DeliveryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Círculo verde de fondo
    paint.color = const Color(0xFFDCFCE7);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 70, paint);

    // checkmark blanco
    paint.color = const Color(0xFF22C55E);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 45, paint);

    paint.color = Colors.white;
    paint.strokeWidth = 4;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width / 2 - 18, size.height / 2 + 2)
      ..lineTo(size.width / 2 - 6, size.height / 2 + 14)
      ..lineTo(size.width / 2 + 18, size.height / 2 - 12);

    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
