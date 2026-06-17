import 'package:flutter/material.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  bool _notifSound = true;
  bool _notifVibrate = true;
  bool _notifTrips = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ajustes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Notificaciones', [
            _buildSwitchItem('Sonido', _notifSound, (v) => setState(() => _notifSound = v)),
            _buildSwitchItem('Vibrar', _notifVibrate, (v) => setState(() => _notifVibrate = v)),
            _buildSwitchItem('Notificaciones de viaje', _notifTrips, (v) => setState(() => _notifTrips = v)),
          ]),
          const SizedBox(height: 16),
          _buildSection('Idioma', [
            _buildInfoItem('Idioma de la app', 'Espa\u00f1ol'),
          ]),
          const SizedBox(height: 16),
          _buildSection('Soporte', [
            _buildLinkItem(Icons.help_outline, 'Centro de ayuda', () {}),
            _buildLinkItem(Icons.report_problem_outlined, 'Reportar un problema', () {}),
            _buildLinkItem(Icons.info_outline, 'Acerca de', () {}),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textGrey)),
        ),
        Container(
          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchItem(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: _primaryDark.withValues(alpha: 0.4), activeThumbColor: _primaryDark,
      dense: true,
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Text(value, style: TextStyle(fontSize: 14, color: _textGrey)),
      dense: true,
    );
  }

  Widget _buildLinkItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 22, color: _textGrey),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      dense: true,
    );
  }
}
