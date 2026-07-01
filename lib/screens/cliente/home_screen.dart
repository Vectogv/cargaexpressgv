import 'dart:async';

import 'package:flutter/material.dart';
import '../../contracts/trip_status.dart';
import '../../contracts/socket_events.dart';
import '../../services/api_client.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../user/auth_screen.dart';
import '../conductor/notifications_screen.dart';
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
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _white = Colors.white;

  int _selectedNavIndex = 0;

  Map<String, dynamic>? _activeTrip;
  bool _loading = true;
  int _notifUnread = 0;
  bool _redirected = false;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    _notifUnread = NotificationService.instance.unreadCount;
    _loadActiveTrip();

    _socketSub = NotificationService.instance.onNotification.listen((event) {
      final tipo = event['__event'] as String?;

      if (tipo == SocketEvents.tripStatusChanged || tipo == SocketEvents.tripCancelled) {
        _loadActiveTrip();
      }

      if (tipo == SocketEvents.tripCancelled && mounted) {
        CacheService.instance.clearDriverPosition();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El viaje ha sido cancelado por el conductor')),
        );
      }

      // Redirigir a RastreoScreen cuando llegan ofertas
      if (tipo == SocketEvents.newOffer && mounted && _activeTrip != null) {
        // Solo redirigir si estamos en la pantalla raíz (evitar push duplicado)
        final route = ModalRoute.of(context);
        if (route?.isFirst == true) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RastreoScreen()));
        }
      }

      if (mounted) setState(() => _notifUnread = NotificationService.instance.unreadCount);
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
      if (trip != null) {
        CacheService.instance.cacheActiveTrip(trip);
        if (mounted) {
          setState(() { _activeTrip = trip; _loading = false; });
          if (!_redirected) {
            _redirected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _redirectToTracking();
            });
          }
        }
      } else {
        CacheService.instance.clearActiveTrip();
        if (mounted) setState(() { _activeTrip = null; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _redirectToTracking() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RastreoScreen()),
    ).then((_) {
      _redirected = false;
      _loadActiveTrip();
    });
  }

  String _estadoLabel(String? estado) {
    switch (estado) {
      case TripStatus.buscando: return 'Buscando conductor';
      case TripStatus.aceptado: return 'Conductor asignado';
      case TripStatus.enCamino: return 'Conductor en camino';
      case TripStatus.llegada: return 'Conductor llegó';
      case TripStatus.enCurso: return 'En camino a destino';
      case TripStatus.esperaConfirmacion: return 'Entrega completada';
      case TripStatus.finalizado: return 'Finalizado';
      case TripStatus.cancelado: return 'Cancelado';
      default: return estado ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Builder(builder: (ctx) {
            return GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'CargaExpress',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Spacer(),
          _badgeIcon(Icons.notifications_outlined, _notifUnread, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
        ],
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count, VoidCallback? onTap) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon, color: const Color(0xFF1A1A2E), size: 22),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (count > 0)
          Positioned(
            right: 2, top: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoTripView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¡Bienvenido, ${ApiClient.instance.nombre}${ApiClient.instance.apellido != null && ApiClient.instance.apellido!.isNotEmpty ? ' ${ApiClient.instance.apellido}' : ''}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Qué deseas hacer hoy?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NuevoEnvioScreen()),
                ).then((_) => _loadActiveTrip()),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: const Text(
                  'Solicitar viaje',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: _white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Viaje en curso',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _estadoLabel(estado),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue, const Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: _primaryBlue.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 32),
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
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
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
                              Text('${conductor['tipoVehiculo'] ?? ''} \u00b7 ${conductor['placa'] ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
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
                      foregroundColor: _primaryBlue,
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

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() => _selectedNavIndex = index);
          _onNavTap(index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: _white,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: const Color(0xFFAAAAAA),
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
        items: _navItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon, size: 24),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen()));
        break;
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: _primaryBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
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
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
    });
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
