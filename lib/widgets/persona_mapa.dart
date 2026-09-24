import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Verde de marca para el cliente / punto de recogida.
const Color colorPersonaCliente = Color(0xFF16A34A);

/// Marcador de persona (cabeza y torso) para el mapa: el cliente en el punto
/// de recogida, visto por el conductor. Con [etiqueta] se muestra una
/// pastilla bajo la figura ("Cliente" o su nombre). El centro del widget es
/// el centro de la figura, así el marcador queda sobre la coordenada.
class PersonaMapa extends StatelessWidget {
  final Color color;
  final double tamano;
  final String? etiqueta;
  final bool halo;

  const PersonaMapa({
    super.key,
    this.color = colorPersonaCliente,
    this.tamano = 40,
    this.etiqueta,
    this.halo = true,
  });

  static const double _altoEtiqueta = 22;

  /// Caja que debe tener el `Marker` que lo contiene.
  static Size caja(double tamano, {bool conEtiqueta = false}) => conEtiqueta
      ? Size(math.max(tamano, 120), tamano + 2 * (_altoEtiqueta + 2))
      : Size.square(tamano);

  /// Primer nombre para la etiqueta ("Cliente" si no hay nombre).
  static String etiquetaDe(String? nombre) {
    final partes = (nombre ?? '').trim().split(RegExp(r'\s+'));
    final primero = partes.isEmpty ? '' : partes.first;
    return primero.isEmpty ? 'Cliente' : primero;
  }

  @override
  Widget build(BuildContext context) {
    final figura = SizedBox.square(
      dimension: tamano,
      child: CustomPaint(painter: PintorPersona(color: color, halo: halo)),
    );
    final texto = etiqueta?.trim() ?? '';
    if (texto.isEmpty) return figura;
    final caja = PersonaMapa.caja(tamano, conEtiqueta: true);
    return SizedBox(
      width: caja.width,
      height: caja.height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          figura,
          Positioned(
            bottom: 0,
            child: Container(
              height: _altoEtiqueta,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Text(
                texto,
                maxLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta la persona (cabeza redonda y torso con hombros) con contorno blanco
/// y sombra suave, sobre un halo opcional del mismo color.
class PintorPersona extends CustomPainter {
  final Color color;
  final bool halo;

  const PintorPersona({required this.color, this.halo = true});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = size.center(Offset.zero);

    if (halo) {
      canvas.drawCircle(c, s * 0.5, Paint()..color = color.withValues(alpha: 0.14));
      canvas.drawCircle(
        c,
        s * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02
          ..color = color.withValues(alpha: 0.35),
      );
    }

    final silueta = _silueta(s, c);

    // Sombra hacia abajo (luz cenital).
    canvas.save();
    canvas.translate(0, s * 0.05);
    canvas.drawPath(
      silueta,
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );
    canvas.restore();

    // Contorno blanco: separa la figura de cualquier fondo del mapa.
    canvas.drawPath(
      silueta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.08
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.drawPath(silueta, Paint()..color = color..isAntiAlias = true);

    // Brillo en la cabeza y cuello más claro.
    final claro = Color.lerp(color, Colors.white, 0.3)!;
    canvas.drawCircle(Offset(c.dx - s * 0.05, c.dy - s * 0.26), s * 0.045, Paint()..color = claro);
    canvas.drawRRect(
      RRect.fromLTRBR(c.dx - s * 0.05, c.dy - s * 0.05, c.dx + s * 0.05, c.dy + s * 0.02, Radius.circular(s * 0.03)),
      Paint()..color = claro.withValues(alpha: 0.6),
    );
  }

  static Path _silueta(double s, Offset c) {
    final torso = RRect.fromLTRBAndCorners(
      c.dx - s * 0.27, c.dy - s * 0.02, c.dx + s * 0.27, c.dy + s * 0.42,
      topLeft: Radius.circular(s * 0.27),
      topRight: Radius.circular(s * 0.27),
      bottomLeft: Radius.circular(s * 0.07),
      bottomRight: Radius.circular(s * 0.07),
    );
    final cabeza = Rect.fromCircle(center: Offset(c.dx, c.dy - s * 0.2), radius: s * 0.16);
    return Path()
      ..addRRect(torso)
      ..addOval(cabeza);
  }

  @override
  bool shouldRepaint(PintorPersona old) => old.color != color || old.halo != halo;
}
