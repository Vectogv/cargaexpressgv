import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui_compartida.dart' show ColoresApp;

/// Ilustración animada de cada paso (ver [_Ilustracion]).
enum Escena { publicar, ofertas, ruta, pin, conectar, recoger }

class PasoTutorial {
  final Escena escena;
  final String titulo;
  final String texto;
  const PasoTutorial(this.escena, this.titulo, this.texto);
}

const claveTutorialCliente = 'tutorial_cliente_visto';
const claveTutorialConductor = 'tutorial_conductor_visto';

const pasosTutorialCliente = [
  PasoTutorial(Escena.publicar, 'Publica tu envío', 'Indica origen, destino y el precio que quieres pagar.'),
  PasoTutorial(Escena.ofertas, 'Recibe ofertas', 'Los conductores cercanos ofertan. Revisa y acepta la que prefieras.'),
  PasoTutorial(Escena.ruta, 'Sigue tu viaje en vivo', 'Mira en el mapa dónde va tu conductor hasta la entrega.'),
  PasoTutorial(Escena.pin, 'Confirma con el PIN', 'Al recibir la carga, dale tu PIN de entrega al conductor y confirma.'),
];

const pasosTutorialConductor = [
  PasoTutorial(Escena.conectar, 'Conéctate', 'Activa el interruptor del inicio para recibir solicitudes.'),
  PasoTutorial(Escena.ofertas, 'Oferta en solicitudes cercanas', 'Elige un envío cerca de ti y propón tu oferta.'),
  PasoTutorial(Escena.recoger, 'Ve al origen y recoge', 'Cuando el cliente te acepte, ve al punto de recogida y recoge la carga.'),
  PasoTutorial(Escena.pin, 'Entrega con el PIN', 'Pide el PIN al cliente para finalizar. La comisión de la plataforma es del 10 %.'),
];

/// Muestra el tutorial una sola vez (marca [clave] en SharedPreferences).
Future<void> mostrarTutorialSiToca(BuildContext context, String clave, List<PasoTutorial> pasos) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(clave) == true) return;
    if (!context.mounted) return;
    await prefs.setBool(clave, true);
    if (!context.mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _Tutorial(pasos));
  } catch (_) {
    // Sin preferencias disponibles: no se muestra y no se bloquea el inicio.
  }
}

class _Tutorial extends StatefulWidget {
  final List<PasoTutorial> pasos;
  const _Tutorial(this.pasos);

  @override
  State<_Tutorial> createState() => _TutorialState();
}

class _TutorialState extends State<_Tutorial> with SingleTickerProviderStateMixin {
  // Un solo controlador en bucle mueve la ilustración de la página visible.
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  final _paginas = PageController();
  int _i = 0;
  bool _arrancado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    // Sin animaciones del sistema: ilustración quieta en su estado final.
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = 1;
    } else {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _paginas.dispose();
    super.dispose();
  }

  void _cerrar() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final n = widget.pasos.length;
    final ultimo = _i == n - 1;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      content: SizedBox(
        width: 360,
        height: 380,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _paginas,
                itemCount: n,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, k) {
                  final p = widget.pasos[k];
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 150,
                          child: AnimatedBuilder(
                            animation: _ctrl,
                            builder: (_, _) => CustomPaint(
                              size: const Size(double.infinity, 150),
                              painter: _Ilustracion(p.escena, _ctrl.value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(p.titulo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
                        const SizedBox(height: 8),
                        Text(p.texto,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, height: 1.4, color: ColoresApp.textoSecundario)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('${_i + 1} de $n',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: ColoresApp.gris)),
          ],
        ),
      ),
      actions: [
        if (!ultimo) TextButton(onPressed: _cerrar, child: const Text('Saltar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.azul),
          onPressed: () => ultimo
              ? _cerrar()
              : _paginas.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
          child: Text(ultimo ? 'Entendido' : 'Siguiente'),
        ),
      ],
    );
  }
}

/// Tramo [a,b] del ciclo 0..1 llevado a 0..1 (con tope).
double _tramo(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Dibuja la escena de un paso según el avance [t] (0..1) del bucle. Todo se
/// completa antes de t=0,85 y se sostiene, para que el estado final se lea.
class _Ilustracion extends CustomPainter {
  final Escena escena;
  final double t;
  _Ilustracion(this.escena, this.t);

  static void _texto(Canvas c, String s, Offset centro, TextStyle st, {bool izquierda = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
    c.save();
    tp.paint(c, izquierda ? Offset(centro.dx, centro.dy - tp.height / 2) : centro - Offset(tp.width / 2, tp.height / 2));
    c.restore();
  }

  static void _icono(Canvas c, IconData ic, Offset centro, double tam, Color color) {
    if (tam < 1) return;
    _texto(
      c,
      String.fromCharCode(ic.codePoint),
      centro,
      TextStyle(fontSize: tam, fontFamily: ic.fontFamily, package: ic.fontPackage, color: color),
    );
  }

  static void _caja(Canvas c, Rect r, Color relleno, {Color? borde, double radio = 12}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radio));
    c.drawRRect(rr, Paint()..color = relleno);
    if (borde != null) {
      c.drawRRect(
        rr,
        Paint()
          ..color = borde
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final fondo = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(18));
    c.clipRRect(fondo);
    c.drawRRect(fondo, Paint()..color = ColoresApp.azulTenue);
    final m = Offset(s.width / 2, s.height / 2);
    switch (escena) {
      case Escena.publicar:
        final a = Offset(s.width * 0.2, s.height * 0.68), b = Offset(s.width * 0.8, s.height * 0.3);
        final linea = _tramo(t, 0.1, 0.55);
        c.drawLine(
          a,
          Offset.lerp(a, b, linea)!,
          Paint()
            ..color = ColoresApp.azul
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        c.drawCircle(a, 9, Paint()..color = ColoresApp.verde);
        final d = Curves.elasticOut.transform(_tramo(t, 0.5, 0.85));
        _icono(c, Icons.location_on, b.translate(0, -14 * d), 38 * d, ColoresApp.rojo);
        final p = Curves.easeOutBack.transform(_tramo(t, 0.0, 0.3));
        _icono(c, Icons.inventory_2, a.translate(0, -34 - 6 * (1 - p)), 34 * p, ColoresApp.naranja);
      case Escena.ofertas:
        const precios = ['\$ 80.000', '\$ 72.000', '\$ 75.000'];
        for (var k = 0; k < 3; k++) {
          final e = Curves.easeOutCubic.transform(_tramo(t, 0.05 + k * 0.2, 0.3 + k * 0.2));
          final y = 12.0 + k * 44;
          final x = s.width * 0.12 + (1 - e) * s.width;
          final r = Rect.fromLTWH(x, y, s.width * 0.76, 38);
          _caja(c, r, Colors.white, borde: k == 1 ? ColoresApp.verde : ColoresApp.borde);
          _icono(c, Icons.local_shipping, r.centerLeft.translate(22, 0), 22, ColoresApp.azul);
          _texto(c, precios[k], Offset(r.left + 44, r.center.dy),
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro),
              izquierda: true);
          if (k == 1 && t > 0.85) _icono(c, Icons.check_circle, r.centerRight.translate(-20, 0), 22, ColoresApp.verde);
        }
      case Escena.ruta:
        final ruta = Path()
          ..moveTo(s.width * 0.1, s.height * 0.75)
          ..cubicTo(s.width * 0.35, s.height * 0.1, s.width * 0.55, s.height * 1.0, s.width * 0.9, s.height * 0.28);
        c.drawPath(
          ruta,
          Paint()
            ..color = ColoresApp.azul.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        final PathMetric pm = ruta.computeMetrics().first;
        final avance = Curves.easeInOut.transform(_tramo(t, 0.05, 0.85));
        final Tangent? tg = pm.getTangentForOffset(pm.length * avance);
        c.drawCircle(Offset(s.width * 0.1, s.height * 0.75), 7, Paint()..color = ColoresApp.verde);
        _icono(c, Icons.location_on, Offset(s.width * 0.9, s.height * 0.28 - 14), 34, ColoresApp.rojo);
        if (tg != null) {
          c.drawCircle(tg.position, 20, Paint()..color = Colors.white);
          _icono(c, Icons.local_shipping, tg.position, 26, ColoresApp.azul);
        }
      case Escena.pin:
        const w = 44.0, g = 10.0;
        final x0 = m.dx - (4 * w + 3 * g) / 2;
        for (var k = 0; k < 4; k++) {
          final r = Rect.fromLTWH(x0 + k * (w + g), m.dy - 40, w, 56);
          final lleno = t >= 0.12 + k * 0.17;
          _caja(c, r, Colors.white, borde: lleno ? ColoresApp.azul : ColoresApp.bordeCampo);
          if (lleno) {
            _texto(c, '${(k * 3 + 4) % 10}', r.center,
                const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ColoresApp.azulOscuro));
          }
        }
        final ok = Curves.elasticOut.transform(_tramo(t, 0.8, 0.98));
        _icono(c, Icons.check_circle, Offset(m.dx, m.dy + 44), 30 * ok, ColoresApp.verde);
      case Escena.conectar:
        final r = Rect.fromCenter(center: m.translate(0, -14), width: 120, height: 60);
        final on = Curves.easeInOut.transform(_tramo(t, 0.15, 0.45));
        _caja(c, r, Color.lerp(ColoresApp.bordeCampo, ColoresApp.verde, on)!, radio: 30);
        c.drawCircle(Offset(r.left + 30 + 60 * on, r.center.dy), 24, Paint()..color = Colors.white);
        for (var k = 0; k < 3; k++) {
          final e = _tramo(t, 0.5 + k * 0.1, 0.8 + k * 0.05);
          _icono(c, Icons.notifications_active, Offset(m.dx - 50 + k * 50, r.bottom + 26), 24 * e, ColoresApp.naranja);
        }
      case Escena.recoger:
        final van = Offset(s.width * 0.68, s.height * 0.55);
        final e = Curves.easeInOut.transform(_tramo(t, 0.15, 0.7));
        _icono(c, Icons.local_shipping, van, 64, ColoresApp.azul);
        final caja = Offset.lerp(Offset(s.width * 0.18, s.height * 0.62), van.translate(-6, 6), e)!;
        _icono(c, Icons.inventory_2, caja.translate(0, -30 * math.sin(e * math.pi)), 34 * (1 - 0.35 * e), ColoresApp.naranja);
        if (t > 0.8) _icono(c, Icons.check_circle, van.translate(0, -48), 26, ColoresApp.verde);
    }
  }

  @override
  bool shouldRepaint(_Ilustracion o) => o.t != t || o.escena != escena;
}
