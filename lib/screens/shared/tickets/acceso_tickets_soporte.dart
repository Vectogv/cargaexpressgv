import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../ui_compartida.dart';
import 'mis_tickets_screen.dart';
import 'nuevo_ticket_screen.dart';

/// Tarjeta de entrada a los tickets de soporte ("Mis tickets" / "Nuevo
/// ticket") para las pantallas de Soporte del cliente y del conductor. Sin
/// sesión (p. ej. cuenta suspendida desde la bienvenida) explica que debe
/// iniciar sesión.
class AccesoTicketsSoporte extends StatelessWidget {
  /// Por defecto se mira si hay token; en pruebas se puede forzar.
  final bool? conSesion;

  const AccesoTicketsSoporte({super.key, this.conSesion});

  @override
  Widget build(BuildContext context) {
    final sesion = conSesion ?? ApiClient.instance.token != null;
    return TarjetaBlanca(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.confirmation_number_outlined, color: ColoresApp.azul, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tickets de soporte',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ColoresApp.textoOscuro),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sesion
                ? 'Cuéntanos tu problema y te respondemos por aquí. Te avisamos con una notificación cada vez que haya respuesta.'
                : 'Inicia sesión para abrir un ticket o ver los que ya tienes. Si tu cuenta está suspendida, '
                    'inicia sesión igualmente: podrás escribirnos para saber el motivo.',
            key: sesion ? null : const Key('tickets_sin_sesion'),
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563), height: 1.4),
          ),
          if (sesion) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BotonPrincipal(
                    key: const Key('btn_mis_tickets'),
                    texto: 'Mis tickets',
                    alto: 46,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MisTicketsScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BotonSecundario(
                    key: const Key('btn_nuevo_ticket_acceso'),
                    texto: 'Nuevo ticket',
                    alto: 46,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NuevoTicketScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
