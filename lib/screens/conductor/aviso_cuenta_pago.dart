import 'dart:ui' show ImageFilter, PathMetric;

import 'package:flutter/material.dart';
import '../shared/ui_compartida.dart';
import '../../core/formato_dinero.dart';

/// Situación de la deuda de comisión del conductor según
/// GET /api/payment/debt (`estadoCuenta`, `montoDeuda`, `deudaFechaLimite`).
enum EstadoPagoConductor {
  alDia,
  conDeuda,
  suspendida,
  enRevision;

  /// El backend rechaza conectarse y ofertar (403 CUENTA_SUSPENDIDA_POR_PAGO).
  bool get bloqueaConexion => this == suspendida || this == enRevision;
}

const String codigoSuspensionPago = 'CUENTA_SUSPENDIDA_POR_PAGO';

/// 403 cuando la deuda de comisión supera el tope (`DRIVER_DEBT_MAX_AMOUNT`),
/// aunque la cuenta siga 'activa': mismo diálogo que la suspensión por pago
/// (ver `cuenta_no_activa_dialog.dart`).
const String codigoDeudaSuperaTope = 'DEUDA_SUPERA_TOPE';

num? _numero(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '');

EstadoPagoConductor estadoPagoConductor(Map<String, dynamic>? deuda) {
  switch (deuda?['estadoCuenta']?.toString()) {
    case 'suspension_por_pago':
      return EstadoPagoConductor.suspendida;
    case 'esperando_confirmacion':
      return EstadoPagoConductor.enRevision;
  }
  final monto = _numero(deuda?['montoDeuda']) ?? 0;
  return monto > 0 ? EstadoPagoConductor.conDeuda : EstadoPagoConductor.alDia;
}

String? _dinero(dynamic v) => formatearPesosSiPositivo(_numero(v));

/// Número de un campo del backend (acepta num o texto decimal).
num? numeroDe(dynamic v) => _numero(v);

/// `$12.000` (null si no hay monto positivo).
String? formatoDinero(dynamic v) => _dinero(v);

String? _fecha(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
  if (d == null) return null;
  String dos(int v) => v.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year}';
}

/// Deuda tras `payment:confirmed` ({message, estadoCuenta, montoDeuda,
/// deudaFechaLimite}): `montoDeuda` es lo que queda por pagar (comisiones de
/// viajes terminados mientras se revisaba el comprobante), 0 si quedó al día.
Map<String, dynamic> deudaTrasPagoConfirmado(Map<String, dynamic>? anterior, Map<String, dynamic> evento) {
  final restante = _numero(evento['montoDeuda']) ?? 0;
  return {
    ...?anterior,
    'estadoCuenta': evento['estadoCuenta']?.toString() ?? 'activa',
    'montoDeuda': restante > 0 ? restante : 0,
    'deudaFechaLimite': restante > 0 ? evento['deudaFechaLimite'] : null,
    'montoComprobante': null,
  };
}

/// Mensaje para el conductor cuando el administrador aprueba su pago.
String mensajePagoConfirmado(Map<String, dynamic> evento) {
  final monto = _dinero(evento['montoDeuda']);
  if (monto != null) {
    final fecha = _fecha(evento['deudaFechaLimite']);
    return 'Pago aprobado. Te quedan $monto por pagar${fecha != null ? ' antes del $fecha' : ''}';
  }
  return evento['message']?.toString() ?? 'Tu pago fue confirmado. Ya puedes conectarte.';
}

/// Aviso en el inicio del conductor sobre su deuda de comisión. No muestra
/// nada si está al día.
class AvisoCuentaPago extends StatelessWidget {
  final Map<String, dynamic>? deuda;
  final VoidCallback onAbrirPagos;

  /// Si se da, con la cuenta bloqueada se ofrece también Soporte (p. ej. ya
  /// pagó y sigue suspendido).
  final VoidCallback? onSoporte;

  const AvisoCuentaPago({super.key, required this.deuda, required this.onAbrirPagos, this.onSoporte});

  @override
  Widget build(BuildContext context) {
    final estado = estadoPagoConductor(deuda);
    final alDia = estado == EstadoPagoConductor.alDia;
    // Al aprobarse el pago el aviso se desvanece y queda "Al día".
    return TransicionAlDia(
      alDia: alDia,
      margen: const EdgeInsets.only(bottom: 16),
      child: alDia ? const SizedBox.shrink() : _contenido(estado),
    );
  }

  Widget _contenido(EstadoPagoConductor estado) {

    final monto = _dinero(deuda?['montoDeuda']);
    final fecha = _fecha(deuda?['deudaFechaLimite']);
    final IconData icono;
    final Color color;
    final String titulo;
    final String detalle;
    final String boton;
    switch (estado) {
      case EstadoPagoConductor.suspendida:
        icono = Icons.block;
        color = ColoresApp.rojo;
        titulo = 'Cuenta suspendida por pago pendiente';
        detalle = '${monto != null ? 'Debes $monto de comisión. ' : ''}'
            'No puedes conectarte ni ofertar hasta que subas el comprobante de pago y sea aprobado.';
        boton = 'Subir comprobante';
        break;
      case EstadoPagoConductor.enRevision:
        icono = Icons.hourglass_top_rounded;
        color = ColoresApp.naranjaTexto;
        titulo = 'Pago en revisión';
        detalle = 'Tu comprobante está en revisión. Podrás conectarte y ofertar cuando el administrador lo apruebe.';
        boton = 'Ver pagos';
        break;
      default:
        icono = Icons.account_balance_wallet_outlined;
        color = ColoresApp.naranja;
        titulo = 'Deuda de comisión${monto != null ? ': $monto' : ''}';
        detalle = fecha != null
            ? 'Paga antes del $fecha para no quedar suspendido.'
            : 'Págala a tiempo para no quedar suspendido.';
        boton = 'Ver cómo pagar';
    }

    return Container(
      key: const Key('aviso_cuenta_pago'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(detalle, style: const TextStyle(fontSize: 12, color: ColoresApp.gris, height: 1.4)),
          const SizedBox(height: 10),
          BotonSecundario(texto: boton, onPressed: onAbrirPagos, color: color, colorBorde: color, alto: 44),
          if (onSoporte != null && estado.bloqueaConexion)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('aviso_pago_soporte'),
                onPressed: onSoporte,
                style: TextButton.styleFrom(foregroundColor: ColoresApp.gris, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.headset_mic_outlined, size: 16),
                label: const Text('¿Ya pagaste? Escríbele a soporte', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Muestra [child] mientras haya deuda. Cuando [alDia] pasa de false a true
/// (pago aprobado), el contenido anterior se va (700 ms: se apaga, baja 14 px
/// y se desenfoca) y entra "Al día" (450 ms) con un check que se dibuja.
/// Si [alDia] ya venía en true se muestra [child] tal cual. Sin animaciones
/// del sistema (`disableAnimations`) salta directo al estado final.
class TransicionAlDia extends StatefulWidget {
  final bool alDia;
  final Widget child;
  final EdgeInsetsGeometry margen;

  const TransicionAlDia({super.key, required this.alDia, required this.child, this.margen = EdgeInsets.zero});

  @override
  State<TransicionAlDia> createState() => _TransicionAlDiaState();
}

class _TransicionAlDiaState extends State<TransicionAlDia> with SingleTickerProviderStateMixin {
  static const _salida = 700, _entrada = 450;
  static const _corte = _salida / (_salida + _entrada);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _salida + _entrada),
  );
  Widget? _anterior;
  bool _transicion = false;

  @override
  void initState() {
    super.initState();
    if (!widget.alDia) _anterior = widget.child;
  }

  @override
  void didUpdateWidget(TransicionAlDia old) {
    super.didUpdateWidget(old);
    if (!widget.alDia) {
      _anterior = widget.child;
      _transicion = false;
      _c.reset();
    } else if (!old.alDia && _anterior != null) {
      _transicion = true;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_transicion) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        if (v < _corte) {
          final t = Curves.easeInOut.transform(v / _corte);
          return Opacity(
            opacity: 1 - t,
            child: Transform.translate(
              offset: Offset(0, 14 * t),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
                child: _anterior,
              ),
            ),
          );
        }
        final t = Curves.easeOut.transform((v - _corte) / (1 - _corte));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, -8 * (1 - t)), child: _alDia(t)),
        );
      },
    );
  }

  Widget _alDia(double trazo) => Padding(
        key: const Key('deuda_al_dia'),
        padding: widget.margen,
        child: TarjetaBlanca(
          radio: 14,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: ColoresApp.verdeFondo, shape: BoxShape.circle),
              child: CustomPaint(painter: _CheckPainter(trazo)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Al día', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ColoresApp.verdeOscuro)),
                SizedBox(height: 2),
                Text('Gerencia aprobó tu pago. Ya puedes conectarte.',
                    style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
              ]),
            ),
          ]),
        ),
      );
}

/// Check (M20,6 L9,17 L4,12 en una caja de 24) dibujado hasta [progreso].
class _CheckPainter extends CustomPainter {
  final double progreso;
  const _CheckPainter(this.progreso);

  @override
  void paint(Canvas canvas, Size size) {
    final e = size.width / 24 * 0.6, dx = size.width * 0.2, dy = size.height * 0.2;
    final path = Path()
      ..moveTo(dx + 4 * e, dy + 12 * e)
      ..lineTo(dx + 9 * e, dy + 17 * e)
      ..lineTo(dx + 20 * e, dy + 6 * e);
    final paint = Paint()
      ..color = ColoresApp.verdeOscuro
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progreso), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progreso != progreso;
}
