import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../shared/tickets/acceso_tickets_soporte.dart';

/// Soporte del conductor: tickets de soporte (Mis tickets / Nuevo ticket),
/// datos de contacto y preguntas frecuentes. También la abre el diálogo de
/// cuenta suspendida (sin sesión: se explica que debe iniciar sesión).
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Map<String, dynamic>? _help;
  bool _loading = true;

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadHelp();
  }

  Future<void> _loadHelp() async {
    // Sin sesión (p. ej. cuenta suspendida desde la bienvenida) el backend
    // responde 401 y eso volvería a cerrar la sesión: se muestra la pantalla
    // sin datos de contacto y se explica.
    if (ApiClient.instance.token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final help = await ApiClient.instance.getHelp();
      if (mounted) setState(() { _help = help; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white, foregroundColor: _textDark, elevation: 0,
        title: const Text('Soporte', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AccesoTicketsSoporte(),
                  const SizedBox(height: 16),
                  _buildContactCard(),
                  const SizedBox(height: 16),
                  const Text('Preguntas frecuentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...(_buildFaqList()),
                ],
              ),
            ),
    );
  }

  Widget _buildContactCard() {
    final contacto = _help?['contacto'] as Map<String, dynamic>?;
    if (ApiClient.instance.token == null) {
      return Container(
        key: const Key('soporte_sin_sesion'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
        child: const Text(
          'Inicia sesión para ver los canales de contacto de soporte. Si tu cuenta está suspendida, '
          'inicia sesión igualmente: verás el motivo y cómo escribirnos.',
          style: TextStyle(fontSize: 13.5, color: _textDark, height: 1.4),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contacto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 12),
          if (contacto?['email'] != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
              title: Text(contacto!['email'] as String),
              contentPadding: EdgeInsets.zero,
            ),
          if (contacto?['telefono'] != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.phone_outlined, color: Color(0xFF1565C0)),
              title: Text(contacto!['telefono'] as String),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFaqList() {
    final faq = (_help?['faq'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (faq.isEmpty) {
      return [const Center(child: Text('No hay preguntas frecuentes disponibles', style: TextStyle(color: Colors.black45)))];
    }
    return faq.map((item) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['pregunta'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (item['respuesta'] != null) ...[
              const SizedBox(height: 6),
              Text(item['respuesta'] as String, style: TextStyle(fontSize: 13, color: _textGrey, height: 1.4)),
            ],
          ],
        ),
      );
    }).toList();
  }
}