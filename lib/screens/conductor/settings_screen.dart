import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/cache_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sonido = true;
  bool _vibrar = true;
  bool _notifViaje = true;
  bool _ubicacion = true;
  bool _visible = true;
  bool _loading = true;

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ApiClient.instance.getSettings();
      if (mounted) setState(() {
        _sonido = settings['notificacionesSonido'] as bool? ?? true;
        _visible = settings['visibilidad'] == 'visible';
        _loading = false;
      });
    } catch (_) {
      _loadFromCache();
    }
  }

  void _loadFromCache() {
    setState(() {
      _sonido = CacheService.instance.getPreference('sonido') as bool? ?? true;
      _vibrar = CacheService.instance.getPreference('vibrar') as bool? ?? true;
      _notifViaje = CacheService.instance.getPreference('notifViaje') as bool? ?? true;
      _ubicacion = CacheService.instance.getPreference('ubicacion') as bool? ?? true;
      _visible = CacheService.instance.getPreference('visible') as bool? ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    CacheService.instance.setPreference('sonido', _sonido);
    CacheService.instance.setPreference('vibrar', _vibrar);
    CacheService.instance.setPreference('notifViaje', _notifViaje);
    CacheService.instance.setPreference('ubicacion', _ubicacion);
    CacheService.instance.setPreference('visible', _visible);

    try {
      await ApiClient.instance.updateSettings({
        'notificacionesSonido': _sonido,
        'visibilidad': _visible ? 'visible' : 'oculto',
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _white, foregroundColor: _textDark, elevation: 0,
        title: const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Notificaciones', [
            _buildSwitchItem('Sonido', _sonido, (v) => setState(() { _sonido = v; _save(); })),
            _buildSwitchItem('Vibrar', _vibrar, (v) => setState(() { _vibrar = v; _save(); })),
            _buildSwitchItem('Notificaciones de viaje', _notifViaje, (v) => setState(() { _notifViaje = v; _save(); })),
          ]),
          const SizedBox(height: 12),
          _buildSection('Privacidad', [
            _buildSwitchItem('Compartir ubicación en vivo', _ubicacion, (v) => setState(() { _ubicacion = v; _save(); })),
            _buildSwitchItem('Visible para clientes', _visible, (v) => setState(() { _visible = v; _save(); })),
          ]),
          const SizedBox(height: 12),
          _buildSection('General', [
            _buildInfoItem('Versión de la app', '1.0.0'),
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
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textGrey)),
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
      activeTrackColor: const Color(0xFF1565C0).withValues(alpha: 0.5),
      activeThumbColor: const Color(0xFF1565C0),
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
}