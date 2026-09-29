import 'package:flutter/material.dart';
import '../shared/soporte_contacto.dart';
import '../shared/tickets/acceso_tickets_soporte.dart';
import '../shared/ui_compartida.dart';

/// Soporte del conductor: tickets de soporte (Mis tickets / Nuevo ticket),
/// datos de contacto y preguntas frecuentes. También la abre el diálogo de
/// cuenta suspendida (sin sesión: se explica que debe iniciar sesión).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: ColoresApp.textoOscuro, elevation: 0,
        title: const Text('Soporte', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            AccesoTicketsSoporte(),
            SizedBox(height: 16),
            ContactoSoporteSection(),
          ],
        ),
      ),
    );
  }
}
