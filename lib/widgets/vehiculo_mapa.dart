import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Dibujo de vehículo visto desde arriba para los marcadores del mapa, con
/// variantes por tipo. El backend guarda `tipoVehiculo` como texto libre
/// (máx. 50); el registro ofrece Motocicleta, Sedan, Camioneta, Camion y
/// Furgon. Cualquier otro valor (o ninguno) se dibuja como camión genérico.
enum TipoVehiculoMapa { moto, carro, camioneta, furgon, camion }

/// Azul de marca para el vehículo del conductor asignado.
const Color colorVehiculoAsignado = Color(0xFF2563EB);

/// Gris oscuro neutro para los vehículos disponibles cercanos.
const Color colorVehiculoCercano = Color(0xFF374151);

String _normalizar(String? texto) {
  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  var t = (texto ?? '').toLowerCase().trim().replaceAll(RegExp(r'[_\-]+'), ' ');
  acentos.forEach((k, v) => t = t.replaceAll(k, v));
  return t;
}

/// Traduce el `tipoVehiculo` del backend a la variante del dibujo.
TipoVehiculoMapa tipoVehiculoMapaDe(String? tipo) {
  final t = _normalizar(tipo);
  if (t.isEmpty) return TipoVehiculoMapa.camion;
  if (t.contains('moto')) return TipoVehiculoMapa.moto;
  // "camioneta" contiene "camion": va antes.
  if (t.contains('camioneta') || t.contains('pickup') || t.contains('pick up')) {
    return TipoVehiculoMapa.camioneta;
  }
  if (t.contains('furgon') || RegExp(r'\bvan\b').hasMatch(t)) return TipoVehiculoMapa.furgon;
  if (t.contains('sedan') || t.contains('carro') || t.contains('automovil') ||
      t.contains('hatchback') || t.contains('taxi') || RegExp(r'\bauto\b').hasMatch(t)) {
    return TipoVehiculoMapa.carro;
  }
  return TipoVehiculoMapa.camion;
}

// ---------------------------------------------------------------------------
// Geometría: rumbo e interpolación.
// ---------------------------------------------------------------------------

double _rad(double g) => g * math.pi / 180;

/// Distancia en metros entre dos puntos (haversine).
double distanciaMetros(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Normaliza un ángulo en grados a [0, 360).
double normalizarGrados(double g) {
  final r = g % 360;
  return r < 0 ? r + 360 : r;
}

/// Rumbo inicial (grados desde el norte, sentido horario) de [a] hacia [b].
double rumboEntre(LatLng a, LatLng b) {
  final f1 = _rad(a.latitude);
  final f2 = _rad(b.latitude);
  final dl = _rad(b.longitude - a.longitude);
  final y = math.sin(dl) * math.cos(f2);
  final x = math.cos(f1) * math.sin(f2) - math.sin(f1) * math.cos(f2) * math.cos(dl);
  return normalizarGrados(math.atan2(y, x) * 180 / math.pi);
}

/// Rumbo del movimiento de [anterior] a [nuevo], o null si el desplazamiento
/// es menor que [umbralM] (ruido del GPS: el vehículo no se voltea).
double? rumboSiSeMovio(LatLng? anterior, LatLng nuevo, {double umbralM = 5}) {
  if (anterior == null) return null;
  if (distanciaMetros(anterior, nuevo) < umbralM) return null;
  return rumboEntre(anterior, nuevo);
}

/// Interpola de [desde] a [hasta] (grados) por el giro más corto.
double interpolarAngulo(double desde, double hasta, double t) {
  final delta = ((hasta - desde) % 360 + 540) % 360 - 180;
  return normalizarGrados(desde + delta * t);
}

/// Rumbo enviado en un payload de ubicación (`heading`, `bearing`, `rumbo`
/// o `course`), o null si no viene o no es válido.
double? rumboDePayload(Map<String, dynamic> data) {
  for (final k in const ['heading', 'bearing', 'rumbo', 'course']) {
    final v = data[k];
    final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    if (n != null && n.isFinite && n >= 0) return normalizarGrados(n);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Dibujo.
// ---------------------------------------------------------------------------

/// Marcador: el vehículo (rotado a [rumbo], grados desde el norte) y, si
/// hay [etiqueta], una pastilla bajo él que no rota. El centro del widget es
/// el centro del vehículo, así el marcador queda sobre la coordenada.
class VehiculoMapa extends StatelessWidget {
  final TipoVehiculoMapa tipo;
  final Color color;
  final double rumbo;
  final double tamano;
  final String? etiqueta;
  final bool halo;

  const VehiculoMapa({
    super.key,
    this.tipo = TipoVehiculoMapa.camion,
    this.color = colorVehiculoAsignado,
    this.rumbo = 0,
    this.tamano = 48,
    this.etiqueta,
    this.halo = false,
  });

  static const double _altoEtiqueta = 22;

  /// Caja que debe tener el `Marker` que lo contiene.
  static Size caja(double tamano, {bool conEtiqueta = false}) => conEtiqueta
      ? Size(math.max(tamano, 120), tamano + 2 * (_altoEtiqueta + 2))
      : Size.square(tamano);

  @override
  Widget build(BuildContext context) {
    final vehiculo = SizedBox.square(
      dimension: tamano,
      child: CustomPaint(
        painter: PintorVehiculo(tipo: tipo, color: color, rumbo: rumbo, halo: halo),
      ),
    );
    final texto = etiqueta?.trim() ?? '';
    if (texto.isEmpty) return Center(child: vehiculo);
    final caja = VehiculoMapa.caja(tamano, conEtiqueta: true);
    return SizedBox(
      width: caja.width,
      height: caja.height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          vehiculo,
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta el vehículo visto desde arriba, con el frente hacia el norte antes
/// de rotar. La sombra se desplaza siempre hacia abajo en pantalla (luz
/// cenital fija) aunque el vehículo gire.
class PintorVehiculo extends CustomPainter {
  final TipoVehiculoMapa tipo;
  final Color color;
  final double rumbo;
  final bool halo;

  const PintorVehiculo({
    required this.tipo,
    required this.color,
    this.rumbo = 0,
    this.halo = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final centro = size.center(Offset.zero);
    final giro = _rad(rumbo);

    if (halo) {
      canvas.drawCircle(centro, s * 0.5, Paint()..color = color.withValues(alpha: 0.14));
      canvas.drawCircle(
        centro,
        s * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02
          ..color = color.withValues(alpha: 0.35),
      );
    }

    final silueta = _silueta(s);

    canvas.save();
    canvas.translate(centro.dx, centro.dy + s * 0.045);
    canvas.rotate(giro);
    canvas.drawPath(
      silueta,
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(giro);
    // Contorno blanco: separa el vehículo de cualquier fondo del mapa.
    canvas.drawPath(
      silueta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    switch (tipo) {
      case TipoVehiculoMapa.moto:
        _moto(canvas, s);
      case TipoVehiculoMapa.carro:
        _carro(canvas, s);
      case TipoVehiculoMapa.camioneta:
        _camioneta(canvas, s);
      case TipoVehiculoMapa.furgon:
        _furgon(canvas, s);
      case TipoVehiculoMapa.camion:
        _camion(canvas, s);
    }
    canvas.restore();
  }

  Color get _oscuro => Color.lerp(color, Colors.black, 0.38)!;
  Color get _claro => Color.lerp(color, Colors.white, 0.22)!;
  Color get _vidrio => Color.lerp(Colors.white, color, 0.14)!;
  Paint _p(Color c) => Paint()..color = c..isAntiAlias = true;

  static RRect _rr(double l, double t, double r, double b, double radio) =>
      RRect.fromLTRBR(l, t, r, b, Radius.circular(radio));

  Path _silueta(double s) {
    switch (tipo) {
      case TipoVehiculoMapa.moto:
        return Path()
          ..addRRect(_rr(-s * 0.1, -s * 0.33, s * 0.1, s * 0.33, s * 0.1))
          ..addRRect(_rr(-s * 0.18, -s * 0.22, s * 0.18, -s * 0.17, s * 0.025));
      case TipoVehiculoMapa.carro:
        return Path()..addRRect(_rr(-s * 0.2, -s * 0.38, s * 0.2, s * 0.38, s * 0.13));
      case TipoVehiculoMapa.camioneta:
        return Path()..addRRect(_rr(-s * 0.21, -s * 0.42, s * 0.21, s * 0.42, s * 0.09));
      case TipoVehiculoMapa.furgon:
        return Path()..addRRect(_rr(-s * 0.22, -s * 0.44, s * 0.22, s * 0.44, s * 0.08));
      case TipoVehiculoMapa.camion:
        return Path()
          ..addRRect(_rr(-s * 0.21, -s * 0.46, s * 0.21, -s * 0.2, s * 0.08))
          ..addRRect(_rr(-s * 0.23, -s * 0.18, s * 0.23, s * 0.46, s * 0.04));
    }
  }

  void _faros(Canvas canvas, double s, double frente, double ancho) {
    final p = _p(const Color(0xFFFFF4C2));
    canvas.drawCircle(Offset(-ancho, frente + s * 0.03), s * 0.028, p);
    canvas.drawCircle(Offset(ancho, frente + s * 0.03), s * 0.028, p);
  }

  void _espejos(Canvas canvas, double s, double y, double x) {
    final p = _p(_oscuro);
    canvas.drawRRect(_rr(-x - s * 0.06, y, -x, y + s * 0.04, s * 0.015), p);
    canvas.drawRRect(_rr(x, y, x + s * 0.06, y + s * 0.04, s * 0.015), p);
  }

  void _moto(Canvas canvas, double s) {
    final llanta = _p(const Color(0xFF1F2937));
    canvas.drawRRect(_rr(-s * 0.045, -s * 0.33, s * 0.045, -s * 0.18, s * 0.04), llanta);
    canvas.drawRRect(_rr(-s * 0.05, s * 0.17, s * 0.05, s * 0.33, s * 0.04), llanta);
    // Manubrio.
    canvas.drawRRect(_rr(-s * 0.18, -s * 0.22, s * 0.18, -s * 0.17, s * 0.025), _p(_oscuro));
    // Cuerpo.
    canvas.drawOval(Rect.fromLTRB(-s * 0.09, -s * 0.24, s * 0.09, s * 0.24), _p(color));
    // Casco del conductor.
    canvas.drawCircle(Offset(0, s * 0.02), s * 0.085, _p(_oscuro));
    canvas.drawCircle(Offset(-s * 0.025, -s * 0.005), s * 0.028, _p(_claro));
    canvas.drawCircle(Offset(0, -s * 0.31), s * 0.022, _p(const Color(0xFFFFF4C2)));
  }

  void _carro(Canvas canvas, double s) {
    const f = -0.38;
    canvas.drawRRect(_rr(-s * 0.2, s * f, s * 0.2, s * 0.38, s * 0.13), _p(color));
    _espejos(canvas, s, -s * 0.12, s * 0.2);
    // Parabrisas.
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.15, -s * 0.13)
        ..lineTo(s * 0.15, -s * 0.13)
        ..lineTo(s * 0.12, -s * 0.22)
        ..quadraticBezierTo(0, -s * 0.25, -s * 0.12, -s * 0.22)
        ..close(),
      _p(_vidrio),
    );
    // Techo.
    canvas.drawRRect(_rr(-s * 0.15, -s * 0.11, s * 0.15, s * 0.17, s * 0.05), _p(_claro));
    // Vidrio trasero.
    canvas.drawRRect(_rr(-s * 0.13, s * 0.19, s * 0.13, s * 0.26, s * 0.03), _p(_vidrio));
    _faros(canvas, s, s * f, s * 0.12);
  }

  void _camioneta(Canvas canvas, double s) {
    const f = -0.42;
    canvas.drawRRect(_rr(-s * 0.21, s * f, s * 0.21, s * 0.42, s * 0.09), _p(color));
    _espejos(canvas, s, -s * 0.2, s * 0.21);
    canvas.drawRRect(_rr(-s * 0.16, -s * 0.26, s * 0.16, -s * 0.17, s * 0.03), _p(_vidrio));
    canvas.drawRRect(_rr(-s * 0.16, -s * 0.15, s * 0.16, s * 0.0, s * 0.04), _p(_claro));
    canvas.drawRRect(_rr(-s * 0.15, s * 0.01, s * 0.15, s * 0.04, s * 0.015), _p(_vidrio));
    // Platón abierto.
    canvas.drawRRect(_rr(-s * 0.16, s * 0.08, s * 0.16, s * 0.37, s * 0.03), _p(_oscuro));
    final linea = _p(color.withValues(alpha: 0.6))..strokeWidth = s * 0.015;
    for (final y in const [0.18, 0.27]) {
      canvas.drawLine(Offset(-s * 0.14, s * y), Offset(s * 0.14, s * y), linea);
    }
    _faros(canvas, s, s * f, s * 0.13);
  }

  void _furgon(Canvas canvas, double s) {
    const f = -0.44;
    canvas.drawRRect(_rr(-s * 0.22, s * f, s * 0.22, s * 0.44, s * 0.08), _p(color));
    _espejos(canvas, s, -s * 0.25, s * 0.22);
    canvas.drawRRect(_rr(-s * 0.17, -s * 0.33, s * 0.17, -s * 0.24, s * 0.035), _p(_vidrio));
    // Techo del furgón con nervaduras.
    canvas.drawRRect(_rr(-s * 0.18, -s * 0.2, s * 0.18, s * 0.4, s * 0.04), _p(_claro));
    final linea = _p(_oscuro.withValues(alpha: 0.35))..strokeWidth = s * 0.012;
    for (final y in const [-0.05, 0.1, 0.25]) {
      canvas.drawLine(Offset(-s * 0.16, s * y), Offset(s * 0.16, s * y), linea);
    }
    _faros(canvas, s, s * f, s * 0.14);
  }

  void _camion(Canvas canvas, double s) {
    const f = -0.46;
    // Cabina.
    canvas.drawRRect(_rr(-s * 0.21, s * f, s * 0.21, -s * 0.2, s * 0.08), _p(_oscuro));
    _espejos(canvas, s, -s * 0.34, s * 0.21);
    canvas.drawRRect(_rr(-s * 0.16, -s * 0.4, s * 0.16, -s * 0.32, s * 0.035), _p(_vidrio));
    canvas.drawRRect(_rr(-s * 0.15, -s * 0.3, s * 0.15, -s * 0.23, s * 0.03), _p(color));
    // Caja de carga.
    canvas.drawRRect(_rr(-s * 0.23, -s * 0.18, s * 0.23, s * 0.46, s * 0.04), _p(color));
    canvas.drawRRect(_rr(-s * 0.19, -s * 0.14, s * 0.19, s * 0.42, s * 0.03), _p(_claro));
    final linea = _p(_oscuro.withValues(alpha: 0.3))..strokeWidth = s * 0.012;
    for (final y in const [0.0, 0.14, 0.28]) {
      canvas.drawLine(Offset(-s * 0.17, s * y), Offset(s * 0.17, s * y), linea);
    }
    _faros(canvas, s, s * f, s * 0.13);
  }

  @override
  bool shouldRepaint(PintorVehiculo old) =>
      old.tipo != tipo || old.color != color || old.rumbo != rumbo || old.halo != halo;
}
