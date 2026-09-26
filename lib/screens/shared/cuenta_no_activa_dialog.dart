import 'package:flutter/material.dart';
import '../../services/api/http_client.dart';
import '../cliente/pagos_screen.dart';
import '../conductor/support_screen.dart';
import 'ui_compartida.dart';
import '../../core/formato_dinero.dart';

/// El backend responde 403 `{ error, code: 'CUENTA_NO_ACTIVA', estadoCuenta,
/// montoDeuda }` cuando el cliente tiene deuda (suspension_por_pago) o un
/// comprobante en revisión (esperando_confirmacion) y trata de pedir un
/// viaje (POST /api/trips/request o /api/trips/reserve).
///
/// Compatibilidad: mientras el backend viejo sólo manda el texto plano
/// "Tu cuenta no está activa. No puedes solicitar viajes." (sin `code`),
/// también se reconoce por el mensaje.
bool esCuentaNoActiva(Object error) {
  if (error is! ApiException) return false;
  if (error.code == 'CUENTA_NO_ACTIVA') return true;
  return error.message.contains('no está activa');
}

/// Muestra el diálogo de cuenta no activa a partir del [ApiException] que
/// devolvió el backend. Vuelve cuando el diálogo se cierra (con o sin ir a
/// Pagos). [onIrAPagos] cambia el destino del botón (p. ej. Ganancias/Pagos
/// del conductor); sin él se abre Pagos del cliente.
Future<void> mostrarCuentaNoActivaDialog(BuildContext context, ApiException error, {VoidCallback? onIrAPagos}) {
  final estadoCuenta = error.data?['estadoCuenta']?.toString();
  final montoDeuda = error.data?['montoDeuda'];
  return showDialog<void>(
    context: context,
    builder: (_) => CuentaNoActivaDialog(
      mensaje: error.message,
      estadoCuenta: estadoCuenta,
      montoDeuda: montoDeuda,
      onIrAPagos: onIrAPagos,
    ),
  );
}

/// Cuenta suspendida por el administrador (403 `CUENTA_SUSPENDIDA` o socket
/// "Cuenta suspendida"): no es por pago, así que se ofrece Soporte.
Future<void> mostrarCuentaSuspendidaDialog(BuildContext context, String mensaje, {VoidCallback? onSoporte}) {
  return showDialog<void>(
    context: context,
    builder: (_) => CuentaSuspendidaDialog(mensaje: mensaje, onSoporte: onSoporte),
  );
}

/// Diálogo "Tienes un saldo pendiente" / "Pago en revisión": mismo estilo que
/// las pantallas rediseñadas (llegada_al_destino_screen, conductor_en_la_zona
/// y RechazarEntregaDialog).
class CuentaNoActivaDialog extends StatelessWidget {
  final String mensaje;
  final String? estadoCuenta;
  final dynamic montoDeuda;

  /// Qué abrir al tocar "Ir a Pagos" (por defecto, Pagos del cliente).
  final VoidCallback? onIrAPagos;

  const CuentaNoActivaDialog({
    super.key,
    required this.mensaje,
    this.estadoCuenta,
    this.montoDeuda,
    this.onIrAPagos,
  });

  bool get _enRevision => estadoCuenta == 'esperando_confirmacion';

  String get _titulo => _enRevision ? 'Pago en revisión' : 'Tienes un saldo pendiente';

  String get _textoBoton => _enRevision ? 'Ver estado del pago' : 'Ir a Pagos';

  String? get _montoFormateado => formatearPesosSiPositivo(montoDeuda);

  @override
  Widget build(BuildContext context) {
    final color = _enRevision ? const Color(0xFF2563EB) : const Color(0xFFEA580C);
    final bgIcono = _enRevision ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED);
    final borderIcono = _enRevision ? const Color(0xFFBFDBFE) : const Color(0xFFFED7AA);
    final icono = _enRevision ? Icons.hourglass_top_rounded : Icons.payments_outlined;
    final monto = _montoFormateado;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgIcono,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderIcono),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _titulo,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.45),
            ),
            if (monto != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monto pendiente', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(monto, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const Key('btn_cerrar_cuenta_no_activa'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cerrar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const Key('btn_ir_a_pagos'),
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        final abrir = onIrAPagos;
                        if (abrir != null) {
                          abrir();
                        } else {
                          navigator.push(MaterialPageRoute(builder: (_) => const PagosScreen()));
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_textoBoton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Cuenta suspendida": mismo estilo que [CuentaNoActivaDialog], con acceso a
/// Soporte en lugar de Pagos (la suspensión no es por deuda).
class CuentaSuspendidaDialog extends StatelessWidget {
  final String mensaje;

  /// Qué abrir al tocar "Contactar a soporte" (por defecto, la pantalla de
  /// soporte con los datos de contacto).
  final VoidCallback? onSoporte;

  const CuentaSuspendidaDialog({super.key, required this.mensaje, this.onSoporte});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Icon(Icons.block_rounded, color: ColoresApp.rojo, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cuenta suspendida',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              key: const Key('mensaje_cuenta_suspendida'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.45),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escríbenos a soporte para saber el motivo y cómo reactivarla.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BotonSecundario(
                    key: const Key('btn_cerrar_cuenta_suspendida'),
                    texto: 'Cerrar',
                    color: const Color(0xFF374151),
                    alto: 48,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotonPrincipal(
                    key: const Key('btn_contactar_soporte'),
                    texto: 'Soporte',
                    icono: Icons.headset_mic_outlined,
                    color: ColoresApp.rojo,
                    alto: 48,
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      final abrir = onSoporte;
                      if (abrir != null) {
                        abrir();
                      } else {
                        navigator.push(MaterialPageRoute(builder: (_) => const SupportScreen()));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
