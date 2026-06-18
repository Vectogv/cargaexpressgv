import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../user/auth_screen.dart';
import 'nuevo_envio_screen.dart';
import 'mis_envios_screen.dart';
import 'rastreo_screen.dart';
import 'perfil_screen.dart';
import 'pagos_screen.dart';
import 'ajustes_screen.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  Map<String, dynamic>? _activeTrip;
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadActiveTrip();
    _socketSub = NotificationService.instance.onNotification.listen((event) {
      final tipo = event['__event'] as String?;
      if (tipo == 'trip:status' || tipo == 'trip:cancelled') {
        _loadActiveTrip();
      }
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted) setState(() { _activeTrip = trip; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _estadoLabel(String? estado) {
    switch (estado) {
      case 'buscando_conductor': return 'Buscando conductor';
      case 'aceptado': return 'Conductor asignado';
      case 'en_curso': return 'En camino a destino';
      case 'completado': return 'Entrega completada';
      case 'finalizado': return 'Finalizado';
      case 'cancelado': return 'Cancelado';
      default: return estado ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _activeTrip != null
                      ? _buildActiveTripView()
                      : _buildNoTripView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Builder(builder: (ctx) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black87),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            );
          }),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _primaryDark, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ApiClient.instance.nombreCompleto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
              const Text('Cliente', style: TextStyle(fontSize: 10, color: Colors.black45)),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildNoTripView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 80, color: _primaryDark.withOpacity(0.15)),
            const SizedBox(height: 20),
            const Text(
              'No hay viajes en curso',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Solicita un transporte de carga para comenzar',
              style: TextStyle(fontSize: 14, color: _textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220, height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NuevoEnvioScreen()),
                ).then((_) => _loadActiveTrip()),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: const Text('Solicitar viaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  foregroundColor: _white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripView() {
    final estado = _activeTrip!['estado'] as String?;
    final origen = _activeTrip!['origen'] as Map<String, dynamic>?;
    final destino = _activeTrip!['destino'] as Map<String, dynamic>?;
    final conductor = _activeTrip!['conductor'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, const Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: _primaryDark.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(Icons.local_shipping, color: _white, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  _estadoLabel(estado),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                if (origen != null || destino != null) ...[
                  const SizedBox(height: 16),
                  if (origen != null)
                    _routeInfo(Icons.trip_origin, 'Origen', origen['direccion'] as String? ?? ''),
                  if (destino != null) ...[
                    const SizedBox(height: 6),
                    _routeInfo(Icons.location_on, 'Destino', destino['direccion'] as String? ?? ''),
                  ],
                ],
                if (conductor != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Text(
                            _initials(conductor['nombre'] as String? ?? ''),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(conductor['nombre'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${conductor['tipoVehiculo'] ?? ''} \u00b7 ${conductor['placa'] ?? ''}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RastreoScreen()),
                    ).then((_) => _loadActiveTrip()),
                    icon: const Icon(Icons.track_changes, size: 20),
                    label: const Text('Ver seguimiento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _white,
                      foregroundColor: _primaryDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeInfo(IconData icon, String label, String dir) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$label: $dir', style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: _primaryDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: _white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(ApiClient.instance.nombreCompleto, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(ApiClient.instance.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerItem(Icons.person_outline, 'Perfil', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen()))),
            _buildDrawerItem(Icons.route_outlined, 'Mis viajes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisEnviosScreen()))),
            _buildDrawerItem(Icons.payments_outlined, 'Pagos', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PagosScreen()))),
            _buildDrawerItem(Icons.settings_outlined, 'Ajustes', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen()))),
            const Spacer(),
            const Divider(),
            _buildDrawerItem(Icons.logout, 'Cerrar sesi\u00f3n', _logout, isDestructive: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback? onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : _textGrey),
      title: Text(label, style: TextStyle(color: isDestructive ? Colors.red : _textDark)),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) onTap();
      },
    );
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }
}
