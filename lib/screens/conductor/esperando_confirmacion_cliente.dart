import 'package:flutter/material.dart';

/// Estado del conductor tras solicitar el cierre (`esperando_confirmacion` /
/// `pendiente_confirmacion`). Sólo el cliente puede confirmar la entrega
/// (`confirmClose` exige rol cliente): aquí el conductor espera y puede
/// consultar el estado.
class EsperandoConfirmacionCliente extends StatelessWidget {
  /// Minutos sin confirmación tras los que un moderador revisa el servicio
  /// (`confirmacionTimeoutMin` de GET /api/config/cliente).
  final int minutosRevision;
  final VoidCallback onActualizar;
  final bool cargando;

  const EsperandoConfirmacionCliente({
    super.key,
    required this.minutosRevision,
    required this.onActualizar,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final minutos = minutosRevision == 1 ? '1 minuto' : '$minutosRevision minutos';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.hourglass_top_rounded, size: 20, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Esperando que el cliente confirme la entrega',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Si el cliente no confirma en $minutos, un moderador revisará el servicio.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575), height: 1.4),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: cargando ? null : onActualizar,
              icon: cargando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      ),
    );
  }
}
