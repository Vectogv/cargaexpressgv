import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../shared/ui_compartida.dart' show ColoresApp;
import 'auth_estilos.dart' show MarcaCargaExpress;
import 'auth_screen.dart';

/// Intro de la primera apertura: un furgón de CargaExpress llega a una calle
/// de Popayán, el ayudante deja una caja en la puerta, el furgón se va y
/// aparece la marca. Después, fundido a la bienvenida (AuthScreen).
///
/// Rendimiento: un solo AnimationController; cielo, montañas, ciudad, calle y
/// andén son capas estáticas (cada una en su RepaintBoundary, pintadas una
/// vez) que solo se desplazan con Transform para el parallax. Lo único que se
/// repinta cada frame es la capa de actores (furgón, persona, caja).
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

/// Duración de la escena; con el fundido de 450 ms suma ~4,5 s.
const Duration _duracion = Duration(milliseconds: 4100);
const double _seg = 4.1;

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: _duracion);
  late final Animation<double> _camara = _ctrl.drive(const _Camara());
  Timer? _espera;
  bool _arrancado = false;
  bool _salio = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Sin movimiento: solo el cierre de marca, quieto, y sigue.
      _ctrl.value = 1;
      _espera = Timer(const Duration(milliseconds: 800), _terminar);
    } else {
      // El futuro de TickerFuture solo se completa si termina normal.
      _ctrl.forward().then((_) => _terminar());
    }
  }

  Future<void> _terminar() async {
    if (_salio) return;
    _salio = true;
    _espera?.cancel();
    _ctrl.stop();
    await ApiClient.instance.marcarIntroVista();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => const AuthScreen(),
      transitionsBuilder: (_, animacion, _, hijo) => FadeTransition(opacity: animacion, child: hijo),
    ));
  }

  @override
  void dispose() {
    _espera?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _azulProfundo,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              container: true,
              label: 'Animación de bienvenida: un furgón de CargaExpress llega a una calle de Popayán, '
                  'deja una caja en la puerta de una casa y se va.',
              child: ExcludeSemantics(child: _escena()),
            ),
            _marca(),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    key: const Key('btn_saltar_intro'),
                    onPressed: _terminar,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _tinta.withValues(alpha: 0.42),
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.only(left: 18, right: 12),
                      shape: const StadiumBorder(),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('Saltar'), SizedBox(width: 2), Icon(Icons.chevron_right_rounded, size: 20)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _escena() {
    return LayoutBuilder(builder: (context, c) {
      final k = c.maxWidth / _ancho;
      final alto = c.maxHeight / k;
      final g = alto * 0.64;
      Widget capa(double factor, double margen, CustomPainter pintor) => Positioned(
            left: -margen * k,
            top: 0,
            bottom: 0,
            width: (_ancho + 2 * margen) * k,
            child: AnimatedBuilder(
              animation: _camara,
              builder: (_, hijo) => Transform.translate(offset: Offset(-_camara.value * factor * k, 0), child: hijo),
              child: RepaintBoundary(child: CustomPaint(painter: pintor)),
            ),
          );
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: _PintorCielo(k, g))),
            capa(0.12, 30, _PintorMontanas(k, g, 30)),
            capa(0.45, 70, _PintorCiudad(k, g, 70)),
            capa(1, 110, _PintorCalle(k, g, 110)),
            RepaintBoundary(child: CustomPaint(painter: _PintorActores(_ctrl, k, g))),
            capa(1.25, 130, _PintorAnden(k, g, alto, 130)),
          ],
        ),
      );
    });
  }

  /// Cierre de marca: el logo crece con un pequeño rebote y el lema sube.
  Widget _marca() {
    final escala = CurvedAnimation(parent: _ctrl, curve: const Interval(0.80, 0.93, curve: Curves.easeOutBack));
    final aparece = CurvedAnimation(parent: _ctrl, curve: const Interval(0.80, 0.87, curve: Curves.easeOut));
    final lema = CurvedAnimation(parent: _ctrl, curve: const Interval(0.86, 0.97, curve: Curves.easeOutCubic));
    return Align(
      alignment: const Alignment(0, -0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: aparece,
              child: ScaleTransition(scale: escala, child: const MarcaCargaExpress(sobreOscuro: true, tamano: 28)),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: lema,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(lema),
                child: Text(
                  'Tus fletes en Popayán, al instante',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guion. t va de 0 a 1 en 4,1 s. Coordenadas de diseño: 390 de ancho; y = 0 es
// la base de las fachadas (g en pantalla), negativo hacia arriba.
// ─────────────────────────────────────────────────────────────────────────────
const double _ancho = 390;
const double _llega = 0.30; // el furgón se detiene
const double _sale = 0.70; // el furgón arranca
const double _fuera = 0.90; // el furgón ya salió
const double _xParado = 165; // trasera del furgón parado
const double _ySuelo = 64; // ruedas sobre la calle
const double _yAnden = 9; // pies de la persona sobre el andén
const double _xEntrega = 118; // donde se detiene la persona
const double _xCaja = 107;

const Color _tinta = Color(0xFF101828);
const Color _azulProfundo = Color(0xFF17459F);
const Color _amarillo = Color(0xFFF6C21C);
const Color _blanco = Colors.white;
final Color _asfalto = Color.lerp(_tinta, ColoresApp.gris, 0.42)!;
final Color _teja = Color.lerp(ColoresApp.naranjaTexto, _blanco, 0.12)!;
final Color _madera = ColoresApp.naranjaAviso;
final Color _carton = Color.lerp(ColoresApp.naranja, _blanco, 0.32)!;

double _tramo(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Avance 0→1 de la llegada: velocidad constante y frenado uniforme en el
/// último 40 % (la desaceleración va al final, como un frenado real).
double _frenado(double u) {
  if (u < 0.6) return u / 0.8;
  final d = u - 0.6;
  return (0.6 + d - d * d / 0.8) / 0.8;
}

double _xFurgon(double t) {
  if (t < _llega) return -260 + (_xParado + 260) * _frenado(_tramo(t, 0, _llega));
  if (t < _sale) return _xParado;
  final u = _tramo(t, _sale, _fuera);
  return _xParado + 640 * u * u * u;
}

/// Cabeceo de la carrocería (radianes; positivo = la trompa baja).
double _cabeceo(double t) {
  final s = t * _seg;
  const sLlega = _llega * _seg;
  const sFreno = 0.6 * _llega * _seg;
  if (t < _sale) {
    if (s < sFreno) return 0;
    if (s < sLlega) return 0.035 * math.min(1, (s - sFreno) / 0.12);
    final d = s - sLlega; // se asienta sobre la suspensión
    return 0.035 * math.exp(-5 * d) * math.cos(13 * d);
  }
  return -0.03 * math.sin(math.pi * math.min(1, _tramo(t, _sale, _fuera) / 0.5));
}

double _camaraEn(double t) {
  if (t < _llega) return -50 * (1 - _frenado(_tramo(t, 0, _llega)));
  if (t < _sale) return 0;
  final u = _tramo(t, _sale, _fuera);
  return 90 * u * u * (3 - 2 * u);
}

class _Camara extends Animatable<double> {
  const _Camara();
  @override
  double transform(double t) => _camaraEn(t);
}

// ─────────────────────────────────────────────────────────────────────────────
// Trazos estáticos: se construyen una sola vez (variables globales perezosas).
// ─────────────────────────────────────────────────────────────────────────────
Paint _p(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Paint _trazo(Color c, double ancho) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = ancho
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

final Paint _sombraSuave = Paint()
  ..color = _tinta.withValues(alpha: 0.30)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

RRect _rr(double l, double t, double r, double b, double radio) =>
    RRect.fromLTRBR(l, t, r, b, Radius.circular(radio));

/// Arco de medio punto (puertas y ventanas coloniales).
Path _arco(double l, double r, double arriba, double abajo) {
  final radio = (r - l) / 2;
  return Path()
    ..moveTo(l, abajo)
    ..lineTo(l, arriba + radio)
    ..arcToPoint(Offset(r, arriba + radio), radius: Radius.circular(radio))
    ..lineTo(r, abajo)
    ..close();
}

// Montañas: cordillera de fondo y el volcán Puracé (cono de cima plana).
final Path _cordillera = Path()
  ..moveTo(-30, 0)
  ..lineTo(-30, -120)
  ..quadraticBezierTo(20, -165, 70, -140)
  ..quadraticBezierTo(115, -118, 150, -150)
  ..quadraticBezierTo(190, -182, 235, -150)
  ..quadraticBezierTo(270, -128, 300, -138)
  ..quadraticBezierTo(370, -160, 420, -125)
  ..lineTo(420, 0)
  ..close();
final Path _purace = Path()
  ..moveTo(190, 0)
  ..quadraticBezierTo(250, -90, 300, -205)
  ..quadraticBezierTo(306, -212, 312, -212)
  ..lineTo(324, -212)
  ..quadraticBezierTo(330, -212, 336, -205)
  ..quadraticBezierTo(380, -100, 430, -40)
  ..lineTo(430, 0)
  ..close();
final Path _cimaPurace = Path()
  ..moveTo(284, -170)
  ..quadraticBezierTo(294, -192, 300, -205)
  ..quadraticBezierTo(306, -212, 312, -212)
  ..lineTo(324, -212)
  ..quadraticBezierTo(330, -212, 336, -205)
  ..quadraticBezierTo(344, -188, 354, -168)
  ..quadraticBezierTo(340, -176, 330, -170)
  ..quadraticBezierTo(318, -180, 306, -172)
  ..quadraticBezierTo(296, -178, 284, -170)
  ..close();

// Ciudad media: iglesia con cúpula y campanario, Torre del Reloj y casonas.
final Path _ciudadBlanca = () {
  final p = Path()
    // Iglesia.
    ..addRect(const Rect.fromLTRB(-40, -112, 120, 0))
    ..addRect(const Rect.fromLTRB(20, -168, 52, -112))
    ..addRect(const Rect.fromLTRB(24, -186, 48, -168))
    ..addOval(Rect.fromCircle(center: const Offset(36, -186), radius: 12))
    ..addOval(Rect.fromCircle(center: const Offset(86, -112), radius: 24))
    ..addRect(const Rect.fromLTRB(84, -146, 88, -132))
    // Casonas de dos pisos a la derecha.
    ..addRect(const Rect.fromLTRB(276, -112, 360, 0))
    ..addRect(const Rect.fromLTRB(360, -98, 460, 0))
    ..addRect(const Rect.fromLTRB(150, -96, 210, 0));
  return p;
}();
final Path _tejadosCiudad = Path()
  ..addPolygon(const [Offset(-46, -112), Offset(-30, -124), Offset(110, -124), Offset(126, -112)], true)
  ..addPolygon(const [Offset(270, -112), Offset(284, -124), Offset(352, -124), Offset(366, -112)], true)
  ..addPolygon(const [Offset(354, -98), Offset(368, -108), Offset(452, -108), Offset(466, -98)], true)
  ..addPolygon(const [Offset(146, -96), Offset(156, -104), Offset(204, -104), Offset(214, -96)], true);
final Path _ventanasCiudad = () {
  final p = Path();
  for (final x in [-24.0, 0.0, 66.0, 96.0]) {
    p.addPath(_arco(x, x + 10, -96, -78), Offset.zero);
  }
  for (final x in [290.0, 316.0, 342.0, 376.0, 404.0, 432.0, 162.0, 186.0]) {
    p.addRRect(_rr(x, -88, x + 10, -70, 1.5));
    p.addRRect(_rr(x, -50, x + 10, -32, 1.5));
  }
  p.addPath(_arco(28, 44, -160, -140), Offset.zero);
  return p;
}();
// Torre del Reloj (ladrillo), con su reloj blanco y remate.
final Path _torre = Path()
  ..addRect(const Rect.fromLTRB(214, -150, 246, 0))
  ..addRect(const Rect.fromLTRB(210, -156, 250, -150))
  ..addRect(const Rect.fromLTRB(218, -186, 242, -156))
  ..addPolygon(const [Offset(214, -186), Offset(230, -212), Offset(246, -186)], true);

// Calle cercana: casas coloniales de un piso; la del medio recibe la caja.
final Path _fachadas = Path()
  ..addRect(const Rect.fromLTRB(-110, -78, 62, 0))
  ..addRect(const Rect.fromLTRB(62, -86, 176, 0))
  ..addRect(const Rect.fromLTRB(292, -80, 500, 0));
final Path _aleros = Path()
  ..addPolygon(const [Offset(-114, -76), Offset(-108, -92), Offset(64, -92), Offset(66, -76)], true)
  ..addPolygon(const [Offset(58, -84), Offset(64, -100), Offset(176, -100), Offset(181, -84)], true)
  ..addPolygon(const [Offset(287, -78), Offset(293, -94), Offset(500, -94), Offset(505, -78)], true);
final Path _lineasTeja = () {
  final p = Path();
  for (var x = -108.0; x < 500; x += 7) {
    if (x > 181 && x < 287) continue;
    p
      ..moveTo(x, -91)
      ..lineTo(x - 1.5, -79);
  }
  return p;
}();
final Path _ventanasCalle = () {
  final p = Path();
  for (final x in [-86.0, -40.0, 8.0, 132.0, 320.0, 384.0, 448.0]) {
    p.addPath(_arco(x, x + 24, -64, -24), Offset.zero);
  }
  return p;
}();
final Path _rejas = () {
  final p = Path();
  for (final x in [-86.0, -40.0, 8.0, 132.0, 320.0, 384.0, 448.0]) {
    for (var i = 1; i < 4; i++) {
      p
        ..moveTo(x + i * 6, -60)
        ..lineTo(x + i * 6, -24);
    }
    p
      ..moveTo(x - 3, -24)
      ..lineTo(x + 27, -24);
  }
  return p;
}();
final Path _puerta = _arco(82, 112, -66, 0);
final Path _puertaVecina = _arco(338, 362, -60, 0);

// Furgón de perfil (mira a la derecha). Origen: suelo bajo la trasera.
final Path _furgonCaja = Path()
  ..addRRect(RRect.fromLTRBAndCorners(2, -92, 102, -24,
      topLeft: const Radius.circular(9), bottomLeft: const Radius.circular(3), topRight: const Radius.circular(3)));
final Path _furgonCabina = Path()
  ..moveTo(100, -24)
  ..lineTo(100, -72)
  ..quadraticBezierTo(100, -77, 105, -77)
  ..lineTo(122, -77)
  ..quadraticBezierTo(127, -77, 130, -72)
  ..lineTo(143, -50)
  ..quadraticBezierTo(146, -46, 151, -45)
  ..quadraticBezierTo(156, -43, 156, -36)
  ..lineTo(156, -26)
  ..quadraticBezierTo(156, -24, 153, -24)
  ..close();
final Path _furgonVidrio = Path()
  ..moveTo(106, -71)
  ..lineTo(121, -71)
  ..quadraticBezierTo(124, -71, 126, -68)
  ..lineTo(137, -50)
  ..lineTo(106, -50)
  ..close();
final Path _pasos = Path()
  ..addOval(Rect.fromCircle(center: const Offset(32, -14), radius: 17))
  ..addOval(Rect.fromCircle(center: const Offset(126, -14), radius: 17));

final Paint _pintCaja = Paint()
  ..shader = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3A75DE), ColoresApp.azul],
  ).createShader(const Rect.fromLTRB(0, -92, 0, -24));
final Paint _pintCabina = Paint()
  ..shader = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2357B8), _azulProfundo],
  ).createShader(const Rect.fromLTRB(0, -77, 0, -24));
final Paint _pintVidrio = Paint()
  ..shader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(ColoresApp.azulTenue, _blanco, 0.4)!, Color.lerp(ColoresApp.azulTenue, ColoresApp.azul, 0.3)!],
  ).createShader(const Rect.fromLTRB(106, -71, 137, -50));

final TextPainter _textoFurgon = TextPainter(
  text: const TextSpan(children: [
    TextSpan(text: 'Carga', style: TextStyle(fontWeight: FontWeight.w500)),
    TextSpan(text: 'Express', style: TextStyle(fontWeight: FontWeight.w800)),
  ], style: TextStyle(fontFamily: 'InstrumentSans', fontSize: 13, color: _blanco, letterSpacing: -0.2)),
  textDirection: TextDirection.ltr,
)..layout();
final TextPainter _textoEntregado = TextPainter(
  text: const TextSpan(
    text: 'Entregado',
    style: TextStyle(fontFamily: 'InstrumentSans', fontSize: 10, fontWeight: FontWeight.w600, color: _blanco),
  ),
  textDirection: TextDirection.ltr,
)..layout();

// ─────────────────────────────────────────────────────────────────────────────
// Capas estáticas.
// ─────────────────────────────────────────────────────────────────────────────
abstract class _CapaFija extends CustomPainter {
  final double k, g;
  const _CapaFija(this.k, this.g);
  @override
  bool shouldRepaint(_CapaFija old) => old.k != k || old.g != g;
}

class _PintorCielo extends _CapaFija {
  const _PintorCielo(super.k, super.g);

  @override
  void paint(Canvas canvas, Size size) {
    final horizonte = g * k;
    final cielo = Rect.fromLTWH(0, 0, size.width, horizonte);
    canvas.drawRect(
      cielo,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.45, 0.78, 1],
          colors: [
            _azulProfundo,
            ColoresApp.azul,
            Color.lerp(ColoresApp.azul, _blanco, 0.55)!,
            Color.lerp(_blanco, _amarillo, 0.32)!,
          ],
        ).createShader(cielo),
    );
    // Resplandor cálido del amanecer detrás del volcán.
    final sol = Offset(size.width * 0.78, horizonte - 120 * k);
    canvas.drawCircle(
      sol,
      230 * k,
      Paint()
        ..shader = RadialGradient(colors: [
          Color.lerp(_blanco, _amarillo, 0.45)!.withValues(alpha: 0.55),
          _amarillo.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: sol, radius: 230 * k)),
    );
    canvas.drawRect(Rect.fromLTRB(0, horizonte, size.width, size.height), _p(_asfalto));
  }
}

class _PintorMontanas extends _CapaFija {
  final double margen;
  const _PintorMontanas(super.k, super.g, this.margen);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(k)
      ..translate(margen, g - 18);
    // Nubes tenues.
    final nube = Paint()
      ..color = _blanco.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas
      ..drawOval(const Rect.fromLTWH(10, -330, 150, 26), nube)
      ..drawOval(const Rect.fromLTWH(220, -280, 120, 20), nube);
    canvas.drawPath(_cordillera, _p(Color.lerp(ColoresApp.azul, _blanco, 0.62)!));
    canvas.drawPath(_purace, _p(Color.lerp(ColoresApp.azul, _blanco, 0.48)!));
    canvas.drawPath(_cimaPurace, _p(Color.lerp(_blanco, ColoresApp.azulTenue, 0.3)!));
    // Fumarola.
    canvas.drawOval(
      const Rect.fromLTWH(304, -246, 34, 26),
      Paint()
        ..color = _blanco.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }
}

class _PintorCiudad extends _CapaFija {
  final double margen;
  const _PintorCiudad(super.k, super.g, this.margen);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(k)
      ..translate(margen, g);
    // La bruma aclara la ciudad lejana (perspectiva atmosférica).
    final bruma = Color.lerp(_blanco, ColoresApp.azulTenue, 0.7)!;
    canvas.drawPath(_ciudadBlanca, _p(bruma));
    canvas.drawPath(_tejadosCiudad, _p(Color.lerp(_teja, bruma, 0.45)!));
    canvas.drawPath(_ventanasCiudad, _p(Color.lerp(ColoresApp.azulOscuro, bruma, 0.55)!));
    canvas.drawPath(_torre, _p(Color.lerp(_teja, bruma, 0.25)!));
    canvas.drawRect(const Rect.fromLTRB(218, -182, 242, -170), _p(Color.lerp(_tinta, bruma, 0.45)!));
    canvas.drawCircle(const Offset(230, -128), 9, _p(_blanco));
    canvas.drawCircle(const Offset(230, -128), 9, _trazo(Color.lerp(_tinta, bruma, 0.4)!, 1.2));
    final aguja = _trazo(_tinta.withValues(alpha: 0.75), 1.4);
    canvas
      ..drawLine(const Offset(230, -128), const Offset(230, -134), aguja)
      ..drawLine(const Offset(230, -128), const Offset(234, -126), aguja);
  }
}

class _PintorCalle extends _CapaFija {
  final double margen;
  const _PintorCalle(super.k, super.g, this.margen);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(k)
      ..translate(margen, g);
    const izq = -110.0, der = 500.0;
    // Andén del fondo y calle.
    canvas.drawRect(const Rect.fromLTRB(izq, 0, der, 14), _p(ColoresApp.borde));
    canvas.drawRect(const Rect.fromLTRB(izq, 14, der, 17), _p(ColoresApp.bordeCampo));
    canvas.drawRect(const Rect.fromLTRB(izq, 17, der, 104), _p(_asfalto));
    final linea = _trazo(_blanco.withValues(alpha: 0.7), 3);
    for (var x = izq; x < der; x += 40) {
      canvas.drawLine(Offset(x, 66), Offset(x + 20, 66), linea);
    }
    // Casas coloniales: blancas, zócalo gris, teja y madera.
    canvas.drawPath(_fachadas, _p(_blanco));
    canvas.drawRect(const Rect.fromLTRB(izq, -9, der, 0), _p(ColoresApp.bordeCampo));
    canvas.drawRect(const Rect.fromLTRB(176, -9, 292, 0), _p(ColoresApp.borde));
    canvas.drawPath(_ventanasCalle, _p(ColoresApp.azulOscuro));
    canvas.drawPath(_rejas, _trazo(_blanco.withValues(alpha: 0.85), 1.2));
    canvas.drawPath(_puerta, _p(_madera));
    canvas.drawPath(_puertaVecina, _p(_madera));
    final tablero = _trazo(_tinta.withValues(alpha: 0.25), 1.2);
    canvas
      ..drawLine(const Offset(97, -50), const Offset(97, -4), tablero)
      ..drawRRect(_rr(78, -3, 116, 0, 1), _p(ColoresApp.chevron))
      ..drawCircle(const Offset(93, -30), 1.6, _p(_amarillo))
      // Farol junto a la puerta.
      ..drawRRect(_rr(119, -64, 125, -54, 1.5), _p(_tinta))
      ..drawCircle(const Offset(122, -58), 2, _p(Color.lerp(_amarillo, _blanco, 0.4)!));
    // Sombra bajo el alero.
    final sombraAlero = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_tinta.withValues(alpha: 0.14), _tinta.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTRB(0, -86, 0, -70));
    canvas
      ..drawRect(const Rect.fromLTRB(-110, -78, 62, -66), sombraAlero)
      ..drawRect(const Rect.fromLTRB(62, -86, 176, -72), sombraAlero)
      ..drawRect(const Rect.fromLTRB(292, -80, 500, -68), sombraAlero);
    canvas.drawPath(_aleros, _p(_teja));
    canvas.drawPath(_lineasTeja, _trazo(Color.lerp(_teja, _tinta, 0.25)!, 1));
  }
}

/// Andén en primer plano: se mueve más rápido que la calle (profundidad).
class _PintorAnden extends _CapaFija {
  final double alto, margen;
  const _PintorAnden(super.k, super.g, this.alto, this.margen);

  @override
  bool shouldRepaint(_PintorAnden old) => super.shouldRepaint(old) || old.alto != alto;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(k)
      ..translate(margen, g);
    const izq = -130.0, der = 520.0;
    final fondo = alto - g;
    canvas.drawRect(const Rect.fromLTRB(izq, 104, der, 112), _p(ColoresApp.bordeCampo));
    canvas.drawRect(
      Rect.fromLTRB(izq, 112, der, fondo),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ColoresApp.fondo, Color.lerp(ColoresApp.borde, ColoresApp.chevron, 0.25)!],
        ).createShader(Rect.fromLTRB(0, 112, 0, fondo)),
    );
    final junta = _trazo(ColoresApp.bordeCampo, 1.2);
    for (var x = izq; x < der; x += 52) {
      canvas.drawLine(Offset(x, 112), Offset(x - 18, fondo), junta);
    }
    canvas.drawLine(const Offset(izq, 150), const Offset(der, 150), junta);
    // Bolardos.
    for (final x in [36.0, 268.0]) {
      canvas.drawOval(Rect.fromLTWH(x - 7, 136, 22, 6), _sombraSuave);
      canvas.drawRRect(_rr(x - 5, 108, x + 5, 140, 4), _p(_tinta));
      canvas.drawRect(Rect.fromLTRB(x - 5, 114, x + 5, 118), _p(_amarillo));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Actores: lo único que se repinta en cada frame.
// ─────────────────────────────────────────────────────────────────────────────
class _PintorActores extends CustomPainter {
  final Animation<double> anim;
  final double k, g;
  _PintorActores(this.anim, this.k, this.g) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    canvas
      ..scale(k)
      ..translate(-_camaraEn(t), g);
    _persona(canvas, t);
    _caja(canvas, t);
    _furgon(canvas, t);
  }

  // Persona: sale de detrás del furgón con la caja, la deja en la puerta y
  // vuelve. Agacharse lleva anticipación (sube un poco) y asentamiento.
  void _persona(Canvas canvas, double t) {
    if (t < 0.31 || t > 0.69) return;
    final double x;
    final double recorrido;
    if (t < 0.46) {
      final u = Curves.easeInOutSine.transform(_tramo(t, 0.31, 0.46));
      x = 182 + (_xEntrega - 182) * u;
      recorrido = (182 - x).abs();
    } else if (t < 0.57) {
      x = _xEntrega;
      recorrido = 0;
    } else {
      final u = Curves.easeInSine.transform(_tramo(t, 0.57, 0.69));
      x = _xEntrega + (190 - _xEntrega) * u;
      recorrido = x - _xEntrega;
    }
    final agache = 8 * math.sin(math.pi * _tramo(t, 0.48, 0.555)) -
        2 * math.sin(math.pi * _tramo(t, 0.46, 0.49)) -
        1.2 * math.sin(math.pi * _tramo(t, 0.555, 0.59));
    final alfa = math.min(_tramo(t, 0.31, 0.33), 1 - _tramo(t, 0.67, 0.69));

    canvas.drawOval(Rect.fromCenter(center: Offset(x, _yAnden), width: 20, height: 4), _sombraSuave);
    if (alfa < 1) canvas.saveLayer(null, Paint()..color = _blanco.withValues(alpha: alfa));
    canvas.save();
    canvas.translate(x, _yAnden);
    if (t >= 0.555) canvas.scale(-1, 1); // de vuelta, mira a la derecha
    _cuerpo(canvas, recorrido / 4.2, agache, t < 0.515);
    canvas.restore();
    if (alfa < 1) canvas.restore();
  }

  /// Figura mirando a la izquierda, pies en y = 0.
  void _cuerpo(Canvas canvas, double fase, double agache, bool cargando) {
    final paso = math.sin(fase);
    final balanceo = (1 - math.cos(2 * fase)) * 0.6;
    final cadera = Offset(0, -17 + agache + balanceo);
    final pantalon = _trazo(_tinta, 4.6);
    final camisa = Color.lerp(ColoresApp.gris, _tinta, 0.2)!;

    void pierna(double lado) {
      final pie = Offset(-lado * paso * 5, -math.max(0, lado * paso) * 2);
      final medio = (cadera + pie) / 2;
      final d = (pie - cadera).distance;
      final dobla = math.sqrt(math.max(0, 9.2 * 9.2 - d * d / 4));
      final rodilla = medio + Offset(-dobla, 0);
      canvas.drawPath(
        Path()
          ..moveTo(cadera.dx, cadera.dy)
          ..lineTo(rodilla.dx, rodilla.dy)
          ..lineTo(pie.dx, pie.dy),
        pantalon,
      );
      canvas.drawRRect(_rr(pie.dx - 3.6, pie.dy - 2.2, pie.dx + 2, pie.dy + 0.6, 1.2), _p(_tinta));
    }

    final hombro = cadera + const Offset(0, -13);
    final brazo = _trazo(camisa, 3.4);
    // Brazo de atrás, piernas, torso, chaleco, cabeza, brazo de adelante.
    if (!cargando) canvas.drawLine(hombro, hombro + Offset(-paso * 5, 11), brazo);
    pierna(-1);
    pierna(1);
    canvas.drawRRect(_rr(cadera.dx - 5.5, hombro.dy - 2, cadera.dx + 5.5, cadera.dy + 1, 4), _p(camisa));
    canvas.drawRRect(_rr(cadera.dx - 5.8, hombro.dy - 1, cadera.dx + 5.8, cadera.dy - 1, 3), _p(_amarillo));
    final reflectivo = _trazo(_blanco.withValues(alpha: 0.9), 1.3)..strokeCap = StrokeCap.butt;
    canvas
      ..drawLine(Offset(-5.8, cadera.dy - 5), Offset(5.8, cadera.dy - 5), reflectivo)
      ..drawLine(Offset(-5.8, cadera.dy - 8.5), Offset(5.8, cadera.dy - 8.5), reflectivo);
    final cabeza = hombro + const Offset(-0.6, -6.4);
    canvas.drawCircle(cabeza, 4.6, _p(_madera));
    // Casco blanco con visera hacia adelante.
    canvas.drawPath(
      Path()
        ..moveTo(cabeza.dx - 5.4, cabeza.dy - 0.6)
        ..arcToPoint(Offset(cabeza.dx + 5.2, cabeza.dy - 0.6), radius: const Radius.circular(5.3))
        ..close(),
      _p(_blanco),
    );
    canvas.drawLine(
      Offset(cabeza.dx - 8, cabeza.dy - 0.4),
      Offset(cabeza.dx + 5.2, cabeza.dy - 0.4),
      _trazo(Color.lerp(_blanco, _tinta, 0.25)!, 1.4),
    );
    if (cargando) {
      canvas.drawLine(hombro, Offset(-9, cadera.dy - 6), brazo);
    } else {
      canvas.drawLine(hombro, hombro + Offset(paso * 5, 11), brazo);
    }
  }

  /// Caja: viaja en las manos, cae con un pequeño rebote y recibe el check.
  void _caja(Canvas canvas, double t) {
    if (t < 0.31) return;
    const suelta = 0.515;
    double x, y;
    if (t < suelta) {
      if (t > 0.69) return;
      final u = Curves.easeInOutSine.transform(_tramo(t, 0.31, 0.46));
      x = 182 + (_xEntrega - 182) * u - 11;
      final agache = 8 * math.sin(math.pi * _tramo(t, 0.48, 0.555)) - 2 * math.sin(math.pi * _tramo(t, 0.46, 0.49));
      y = _yAnden - 12 + agache;
    } else {
      x = _xCaja;
      final alturaSuelta = _yAnden - 12 + 8 * math.sin(math.pi * _tramo(suelta, 0.48, 0.555));
      y = alturaSuelta + (_yAnden - alturaSuelta) * Curves.bounceOut.transform(_tramo(t, suelta, 0.565));
    }
    if (t >= suelta) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, _yAnden), width: 20, height: 3.5), _sombraSuave);
    }
    final alfa = _tramo(t, 0.31, 0.33);
    final caja = _rr(x - 8, y - 13, x + 8, y, 1.6);
    canvas.drawRRect(caja, _p(_carton.withValues(alpha: alfa)));
    canvas.drawRRect(caja, _trazo(ColoresApp.naranjaTexto.withValues(alpha: 0.7 * alfa), 1));
    canvas.drawRect(Rect.fromLTRB(x - 1.6, y - 13, x + 1.6, y), _p(Color.lerp(_carton, _blanco, 0.45)!.withValues(alpha: alfa)));

    // "Entregado": píldora verde que salta sobre la caja.
    final pop = _tramo(t, 0.575, 0.64);
    if (pop <= 0) return;
    final escala = Curves.easeOutBack.transform(pop);
    final ancho = _textoEntregado.width + 26;
    canvas.save();
    canvas.translate(x, _yAnden - 24);
    canvas.scale(escala);
    canvas.drawRRect(_rr(-ancho / 2, -10, ancho / 2, 10, 10).shift(const Offset(0, 1.5)), _sombraSuave);
    canvas.drawRRect(_rr(-ancho / 2, -10, ancho / 2, 10, 10), _p(ColoresApp.verdeOscuro));
    final izq = -ancho / 2 + 10;
    canvas.drawPath(
      Path()
        ..moveTo(izq - 3.5, 0)
        ..lineTo(izq - 1, 2.6)
        ..lineTo(izq + 4, -2.8),
      _trazo(_blanco, 1.8),
    );
    _textoEntregado.paint(canvas, Offset(izq + 7, -_textoEntregado.height / 2));
    canvas.restore();
  }

  void _furgon(Canvas canvas, double t) {
    if (t >= _fuera) return;
    final x = _xFurgon(t);
    final v = (_xFurgon(math.min(1, t + 0.01)) - _xFurgon(math.max(0, t - 0.01))) / 0.02;
    canvas.save();
    canvas.translate(x, _ySuelo);

    // Estelas de velocidad, solo cuando va rápido.
    final intensidad = ((v - 900) / 1800).clamp(0.0, 1.0);
    if (intensidad > 0) {
      final estela = _trazo(_blanco.withValues(alpha: 0.5 * intensidad), 1.6);
      for (final (y, largo) in const [(-80.0, 1.0), (-60.0, 0.7), (-40.0, 0.9)]) {
        canvas.drawLine(Offset(-8 - 46 * largo * intensidad, y), Offset(-8, y), estela);
      }
    }

    // Sombra de contacto.
    canvas.drawOval(const Rect.fromLTRB(-2, -4, 160, 5), _sombraSuave);

    // Carrocería con cabeceo sobre la suspensión.
    canvas.save();
    canvas
      ..translate(80, -14)
      ..rotate(_cabeceo(t))
      ..translate(-80, 14);
    canvas.drawPath(_furgonCaja, _pintCaja);
    canvas.drawPath(_furgonCabina, _pintCabina);
    canvas.drawRect(const Rect.fromLTRB(2, -36, 102, -32), _p(_amarillo));
    canvas.drawLine(const Offset(8, -90), const Offset(96, -90), _trazo(_blanco.withValues(alpha: 0.35), 1.2));
    _textoFurgon.paint(canvas, Offset(52 - _textoFurgon.width / 2, -66));
    canvas.drawPath(_furgonVidrio, _pintVidrio);
    canvas.drawLine(const Offset(110, -52), const Offset(118, -67), _trazo(_blanco.withValues(alpha: 0.45), 2));
    final costura = _trazo(_tinta.withValues(alpha: 0.35), 1);
    canvas
      ..drawLine(const Offset(138, -48), const Offset(138, -28), costura)
      ..drawLine(const Offset(100, -70), const Offset(100, -28), costura)
      ..drawRRect(_rr(126, -45, 133, -43, 1), _p(_tinta.withValues(alpha: 0.5)))
      ..drawRRect(_rr(139, -58, 143, -50, 1.5), _p(_tinta))
      ..drawRRect(_rr(151, -41, 156, -35, 1.5), _p(_blanco))
      ..drawRRect(_rr(2, -44, 6, -34, 1.5), _p(ColoresApp.rojo))
      ..drawRRect(_rr(0, -27, 158, -17, 4), _p(_tinta))
      ..drawRRect(_rr(142, -27, 155, -21, 1.2), _p(_amarillo))
      ..drawRRect(_rr(142, -27, 155, -21, 1.2), _trazo(_tinta, 0.8))
      ..drawPath(_pasos, _p(_tinta));
    canvas.restore();

    // Ruedas: el ángulo sale de la distancia recorrida (ruedan sin patinar).
    final angulo = x / 14;
    final rayo = _trazo(Color.lerp(ColoresApp.chevron, _tinta, 0.35)!, 1.6);
    for (final cx in const [32.0, 126.0]) {
      final c = Offset(cx, -14);
      canvas.drawCircle(c, 14, _p(Color.lerp(_tinta, ColoresApp.gris, 0.2)!));
      canvas.drawCircle(c, 8, _p(ColoresApp.chevron));
      for (var i = 0; i < 5; i++) {
        final a = angulo + i * 2 * math.pi / 5;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * 3, c + Offset(math.cos(a), math.sin(a)) * 7, rayo);
      }
      canvas.drawCircle(c, 2.6, _p(_tinta));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorActores old) => old.anim != anim || old.k != k || old.g != g;
}
