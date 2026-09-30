import 'package:flutter/material.dart';
import '../shared/soporte_contacto.dart';
import '../shared/tickets/acceso_tickets_soporte.dart';
import '../shared/ui_compartida.dart';

/// Soporte del cliente: solo tickets (el chat con moderación es del conductor).
class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: ColoresApp.fondo,
        surfaceTintColor: ColoresApp.fondo,
        foregroundColor: ColoresApp.textoOscuro,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        automaticallyImplyLeading: Navigator.canPop(context),
        title: const Text('Soporte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: const [
          Text('Escríbenos por aquí y te respondemos en la app.', style: TextStyle(fontSize: 14, color: ColoresApp.textoSecundario)),
          SizedBox(height: 16),
          AccesoTicketsSoporte(),
          SizedBox(height: 20),
          _AvisoSos(),
          SizedBox(height: 20),
          _PreguntasFrecuentes(),
          SizedBox(height: 20),
          ContactoSoporteSection(),
        ],
      ),
    );
  }
}

class _AvisoSos extends StatelessWidget {
  const _AvisoSos();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ColoresApp.naranjaFondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.naranjaBorde),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: ColoresApp.naranjaTexto),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Una emergencia durante el viaje?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.naranjaAviso)),
                SizedBox(height: 2),
                Text('Usa el botón SOS del mapa de rastreo. Avisa de inmediato al equipo de CargaExpress.',
                    style: TextStyle(fontSize: 13, color: ColoresApp.naranjaAviso)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreguntasFrecuentes extends StatelessWidget {
  const _PreguntasFrecuentes();

  static const _preguntas = [
    ('¿Qué es el PIN de entrega?',
        'Un código de 4 números que confirma que recibiste la carga. Dáselo al conductor solo cuando la tengas en tus manos.'),
    ('¿Puedo cancelar un envío?', 'Sí, mientras el conductor esté a más de 1 km del punto de recogida.'),
    ('¿Cómo se define el precio?', 'Tú propones un precio, los conductores ofertan y pagas el de la oferta que aceptes.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Preguntas frecuentes',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: ColoresApp.borde)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (var i = 0; i < _preguntas.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 1, color: ColoresApp.divisor),
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedAlignment: Alignment.centerLeft,
                    iconColor: ColoresApp.chevron,
                    collapsedIconColor: ColoresApp.chevron,
                    title: Text(_preguntas[i].$1,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ColoresApp.textoOscuro)),
                    children: [
                      Text(_preguntas[i].$2, style: const TextStyle(fontSize: 14, color: ColoresApp.textoSecundario)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
