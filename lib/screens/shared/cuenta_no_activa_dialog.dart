import 'package:flutter/material.dart';
import '../../services/api/http_client.dart';
import '../cliente/pagos_screen.dart';

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
/// Pagos).
Future<void> mostrarCuentaNoActivaDialog(BuildContext context, ApiException error) {
  final estadoCuenta = error.data?['estadoCuenta']?.toString();
  final montoDeuda = error.data?['montoDeuda'];
  return showDialog<void>(
    context: context,
    builder: (_) => CuentaNoActivaDialog(
      mensaje: error.message,
      estadoCuenta: estadoCuenta,
      montoDeuda: montoDeuda,
    ),
  );
}

/// Diálogo "Tienes un saldo pendiente" / "Pago en revisión": mismo estilo que
/// las pantallas rediseñadas (llegada_al_destino_screen, conductor_en_la_zona
/// y RechazarEntregaDialog).
class CuentaNoActivaDialog extends StatelessWidget {
  final String mensaje;
  final String? estadoCuenta;
  final dynamic montoDeuda;

  const CuentaNoActivaDialog({
    super.key,
    required this.mensaje,
    this.estadoCuenta,
    this.montoDeuda,
  });

  bool get _enRevision => estadoCuenta == 'esperando_confirmacion';

  String get _titulo => _enRevision ? 'Pago en revisión' : 'Tienes un saldo pendiente';

  String get _textoBoton => _enRevision ? 'Ver estado del pago' : 'Ir a Pagos';

  String? get _montoFormateado {
    final v = montoDeuda;
    if (v == null) return null;
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null || n <= 0) return null;
    final miles = n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '\$$miles';
  }

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
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PagosScreen()),
                        );
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
