import 'package:flutter/material.dart';
import '../shared/soporte_contacto.dart';
import '../shared/tickets/acceso_tickets_soporte.dart';

/// Soporte del conductor: tickets de soporte (Mis tickets / Nuevo ticket),
/// datos de contacto y preguntas frecuentes. También la abre el diálogo de
/// cuenta suspendida (sin sesión: se explica que debe iniciar sesión).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white, foregroundColor: _textDark, elevation: 0,
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
