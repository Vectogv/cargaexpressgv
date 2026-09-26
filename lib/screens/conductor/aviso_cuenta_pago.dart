import 'package:flutter/material.dart';
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
    if (estado == EstadoPagoConductor.alDia) return const SizedBox.shrink();

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
        color = Colors.red.shade700;
        titulo = 'Cuenta suspendida por pago pendiente';
        detalle = '${monto != null ? 'Debes $monto de comisión. ' : ''}'
            'No puedes conectarte ni ofertar hasta que subas el comprobante de pago y sea aprobado.';
        boton = 'Subir comprobante';
        break;
      case EstadoPagoConductor.enRevision:
        icono = Icons.hourglass_top_rounded;
        color = Colors.orange.shade800;
        titulo = 'Pago en revisión';
        detalle = 'Tu comprobante está en revisión. Podrás conectarte y ofertar cuando el administrador lo apruebe.';
        boton = 'Ver pagos';
        break;
      default:
        icono = Icons.account_balance_wallet_outlined;
        color = Colors.amber.shade900;
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
              child: Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(detalle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151), height: 1.4)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAbrirPagos,
              style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
              child: Text(boton),
            ),
          ),
          if (onSoporte != null && estado.bloqueaConexion)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('aviso_pago_soporte'),
                onPressed: onSoporte,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF374151), visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.headset_mic_outlined, size: 16),
                label: const Text('¿Ya pagaste? Escríbele a soporte', style: TextStyle(fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }
}
