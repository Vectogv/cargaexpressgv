import 'package:flutter/material.dart';
import '../shared/ui_compartida.dart';

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
        color: ColoresApp.azul.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.azul.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.hourglass_top_rounded, size: 20, color: ColoresApp.azul),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Esperando que el cliente confirme la entrega',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Si el cliente no confirma en $minutos, un moderador revisará el servicio.',
            style: const TextStyle(fontSize: 12, color: ColoresApp.grisClaro, height: 1.4),
          ),
          const SizedBox(height: 10),
          BotonSecundario(texto: 'Actualizar', icono: Icons.refresh, cargando: cargando, onPressed: onActualizar),
        ],
      ),
    );
  }
}
