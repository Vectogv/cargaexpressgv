import 'package:flutter/material.dart';
import '../../contracts/disputa_resultado.dart';
import 'detalle_resolucion_screen.dart';

export '../../contracts/disputa_resultado.dart' show etiquetaResultado;

/// Reembolso con separador de miles (`$15.000`); null si no hay reembolso.
/// El backend lo envía como número o como texto decimal.
String? formatoReembolso(dynamic valor) {
  final n = valor is num ? valor : num.tryParse(valor?.toString() ?? '');
  if (n == null || n <= 0) return null;
  final digitos = n.round().toString();
  final conPuntos = digitos.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '\$$conPuntos';
}

/// Fecha `dd/MM/yyyy` (hora local) de un ISO; null si no es válida.
String? formatoFecha(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
  if (d == null) return null;
  String dos(int v) => v.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year}';
}

String? _texto(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Resolución de una disputa del cliente con los datos de GET /api/disputes/:id.
class ResolucionScreen extends StatelessWidget {
  final Map<String, dynamic> disputa;

  const ResolucionScreen({super.key, required this.disputa});

  @override
  Widget build(BuildContext context) {
    final resultado = etiquetaResultado(disputa['resultado']);
    final reembolso = formatoReembolso(disputa['reembolso']);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                'Resoluci\u00f3n',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(50, 56),
                    painter: _ShieldPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Hemos revisado la disputa\ny tomamos una decisi\u00f3n.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4B5563),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
              const SizedBox(height: 16),
              const Text(
                'Resultado',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                resultado,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF22C55E),
                ),
              ),
              if (consecuenciaParaCliente(disputa['resultado']).isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  consecuenciaParaCliente(disputa['resultado']),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
              if (reembolso != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reembolso',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      reembolso,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
              ],
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleResolucionScreen(
                          disputeNumber: _texto(disputa['numero']) ?? _texto(disputa['id']) ?? '—',
                          problema: etiquetaProblemaDisputa(disputa['problema']),
                          resultado: resultado,
                          reembolso: reembolso,
                          comentarioAdmin: _texto(disputa['comentarioAdmin']),
                          fechaResolucion: formatoFecha(disputa['fechaResolucion']) ?? '—',
                          onVolver: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ver detalle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shieldPaint = Paint()..color = const Color(0xFF22C55E);
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.18)
      ..lineTo(size.width, size.height * 0.55)
      ..cubicTo(size.width, size.height * 0.78, size.width / 2, size.height, size.width / 2, size.height)
      ..cubicTo(size.width / 2, size.height, 0, size.height * 0.78, 0, size.height * 0.55)
      ..lineTo(0, size.height * 0.18)
      ..close();
    canvas.drawPath(path, shieldPaint);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.36);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
