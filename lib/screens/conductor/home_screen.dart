import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_client.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service_client.dart';
import '../../services/driver_location_service.dart';
import '../user/auth_screen.dart';
import 'trip_in_progress_screen.dart';
import 'offers_screen.dart';
import 'earnings_screen.dart';
import 'trip_chat_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'documents_screen.dart';
import 'conductor_trip_detail_screen.dart';
import 'trip_history_screen.dart';
import 'support_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _bottomIndex = 0;
  bool _online = true;
  bool _statusLoading = false;
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _profile;

  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<List<Map<String, dynamic>>>? _tripSub;
  int _knownNearbyCount = 0;
  final Set<String> _offeredTripIds = {};
  final Set<String> _activeBannerIds = {};

  static const Color _primaryBlue = Color(0xFF1A3C6E);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _white = Colors.white;
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _fetchData();

    _socketSub = NotificationService.instance.onNotification.listen((event) async {
      final tipo = event['__event'] as String?;
      if (tipo == 'trip:nearby') {
        if (_activeTrip == null) {
          final tripId = (event['_id'] ?? event['id']).toString();
          if (!_offeredTripIds.contains(tripId)) {
            _showNewTripBanner(event);
          }
        }
      } else if (tipo == 'trip:accepted') {
        final tripId = event['tripId'] ?? event['id'];
        if (tripId != null) {
          DriverLocationService.instance.removeTrip(tripId);
        }
        await _fetchActiveTrip();
        if (_activeTrip != null) {
          CacheService.instance.cacheActiveTrip(_activeTrip!);
          _redirectToActiveTrip();
        }
      } else if (tipo == 'trip:status') {
        final estado = event['estado'] as String?;
        if (estado == 'completado' || estado == 'cancelado') {
          if (mounted) setState(() => _activeTrip = null);
        } else {
          _fetchActiveTrip();
        }
      }
    });

    _tripSub = DriverLocationService.instance.onTripsUpdated.listen((trips) {
      if (_activeTrip != null) return;
      final disponibles = trips.where((t) {
        final id = (t['_id'] ?? t['id']).toString();
        return !_offeredTripIds.contains(id);
      }).toList();
      if (disponibles.length > _knownNearbyCount) {
        final nuevos = disponibles.where((t) => t['notified'] != true).toList();
        if (nuevos.isNotEmpty) {
          for (final t in nuevos) { t['notified'] = true; }
          _showNewTripBanner(nuevos.first);
        }
      }
      _knownNearbyCount = disponibles.length;
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _tripSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await _fetchProfileFirst();
    final cachedTrip = CacheService.instance.getCachedActiveTrip();
    if (cachedTrip != null) {
      final estado = cachedTrip['estado'] as String?;
      if (estado == 'aceptado' || estado == 'en_curso') {
        try {
          final active = await ApiClient.instance.getActiveTrip();
          if (active != null) {
            if (mounted) setState(() => _activeTrip = active);
            CacheService.instance.cacheActiveTrip(active);
            _redirectToActiveTrip();
            return;
          }
        } catch (_) {}
        CacheService.instance.clearActiveTrip();
      }
    }
    await _fetchActiveTrip();
    if (_activeTrip != null) {
      CacheService.instance.cacheActiveTrip(_activeTrip!);
      _redirectToActiveTrip();
      return;
    }
    if (_online) {
      final estado = _verificacionEstado;
      if (estado == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo verificar tu estado. Revisa tu conexión e intenta de nuevo.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
          setState(() => _online = false);
        }
        return;
      }
      if (estado != 'aprobado') return;
      try { await ApiClient.instance.setDriverStatus(true); } catch (_) {}
      if (!await DriverLocationService.instance.start()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso de ubicación denegado. Actívalo en Ajustes.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _redirectToActiveTrip() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripInProgressScreen(trip: _activeTrip)));
    });
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (trip != null) {
        final estado = trip['estado'] as String?;
        if (estado == 'aceptado' || estado == 'en_curso') {
          CacheService.instance.cacheActiveTrip(trip);
          if (mounted) setState(() => _activeTrip = trip);
          return;
        }
      }
      CacheService.instance.clearActiveTrip();
    } catch (_) {
      CacheService.instance.clearActiveTrip();
    }
    if (mounted) setState(() => _activeTrip = null);
  }

  Future<void> _fetchProfileFirst() async {
    try {
      final profile = await ApiClient.instance.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
    }
  }

  Future<void> _toggleStatus() async {
    if (mounted) setState(() => _statusLoading = true);
    try {
      if (!_online) {
        // Verificar estado primero
        final estado = _verificacionEstado;
        if (estado == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargando tu perfil... intenta en un momento'), backgroundColor: Colors.orange),
          );
          return;
        }
        if (estado != 'aprobado') {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tu cuenta no está aprobada para recibir viajes'), backgroundColor: Colors.orange),
          );
          return;
        }
        // Intentar GPS primero
        final gpsOk = await DriverLocationService.instance.start();
        if (!gpsOk) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado. Actívalo en Ajustes.'), backgroundColor: Colors.red),
          );
          return; // NO marcar online si GPS falló
        }
        try { await ApiClient.instance.setDriverStatus(true); } catch (_) {}
        if (mounted) setState(() => _online = true); // Solo aquí
      } else {
        DriverLocationService.instance.pause();
        try { await ApiClient.instance.setDriverStatus(false); } catch (_) {}
        if (mounted) setState(() => _online = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  void _showNewTripBanner(Map<String, dynamic> event) {
    if (!mounted) return;
    final tripId = (event['id'] ?? event['_id'])?.toString();
    if (tripId == null) return;
    if (_activeBannerIds.contains(tripId)) return; // deduplicar
    _activeBannerIds.add(tripId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nueva solicitud de viaje cerca de ti'),
        duration: const Duration(seconds: 25),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () async {
            _offeredTripIds.add(tripId);       // antes de navegar
            _activeBannerIds.remove(tripId);
            _resetNearbyNotificationState();
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => ConductorTripDetailScreen(trip: event),
            ));
          },
        ),
      ),
    );
  }

  void _resetNearbyNotificationState() {
    _knownNearbyCount = 0;
    final trips = DriverLocationService.instance.nearbyTrips;
    for (final t in trips) {
      t.remove('notified');
    }
    DriverLocationService.instance.refreshTrips();
  }

  String? get _verificacionEstado {
    final conductor = _profile?['conductor'] as Map<String, dynamic>?;
    return conductor?['estadoVerificacion'] as String?;
  }

  String _statusLabel() {
    final estado = _verificacionEstado;
    if (estado == 'rechazado' || estado == 'pendiente') return 'Pendiente de verificaci\u00f3n';
    if (!_online) return 'Fuera de l\u00ednea';
    return 'En l\u00ednea';
  }

  Color _statusColor() {
    final estado = _verificacionEstado;
    if (estado == 'rechazado' || estado == 'pendiente') return Colors.orange;
    if (!_online) return Colors.grey;
    return _accentGreen;
  }

  void _navigate(int index) {
    if (index == 5) {
      SocketServiceClient.instance.resetChatUnread();
    }
    final routes = <int, Widget>{
      1: TripInProgressScreen(trip: _activeTrip),
      2: const OffersScreen(),
      4: const EarningsScreen(),
      5: TripChatScreen(trip: _activeTrip),
      6: const NotificationsScreen(),
      9: const ProfileScreen(),
      10: const DocumentsScreen(),
      11: const TripHistoryScreen(),
      12: const SupportScreen(),
      13: const SettingsScreen(),
    };
    final route = routes[index];
    if (route != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => route));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Próximamente disponible'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgLight,
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildHomeContent(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Future<void> _logout() async {
    DriverLocationService.instance.stop();
    await ApiClient.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A3C6E), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _white.withValues(alpha: 0.2),
                  child: Text(
                    _initials(ApiClient.instance.nombreCompleto),
                    style: TextStyle(color: _white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ApiClient.instance.nombreCompleto,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          final estado = _verificacionEstado;
                          if (estado == 'rechazado' || estado == 'pendiente') {
                            Navigator.pop(context);
                            _navigate(10);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusLabel(),
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.person_outline, 'Perfil', 9),
                _buildDrawerItem(Icons.description_outlined, 'Documentaci\u00f3n', 10),
                _buildDrawerItem(Icons.route_outlined, 'Historial de viajes', 11),
                _buildDrawerItem(Icons.chat_bubble_outline, 'Mensajes', 5),
                _buildDrawerItem(Icons.notifications_none, 'Notificaciones', 6),
                _buildDrawerItem(Icons.settings_outlined, 'Ajustes', 13),
                _buildDrawerItem(Icons.headset_mic_outlined, 'Soporte', 12),
                const Divider(),
                _buildDrawerItem(Icons.logout, 'Cerrar sesi\u00f3n', -1, isDestructive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, int index, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : _textGrey),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.red : _textDark,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (index == -1) {
          _logout();
        } else {
          _navigate(index);
        }
      },
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
      _NavItem(icon: Icons.receipt_long_rounded, label: 'Viajes'),
      _NavItem(icon: Icons.bar_chart_rounded, label: 'Ingresos'),
      _NavItem(icon: Icons.person_rounded, label: 'Perfil'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = i == _bottomIndex;
              return GestureDetector(
                onTap: () {
                  if (i == 0) {
                    setState(() => _bottomIndex = 0);
                  } else if (i == 1) {
                    _navigate(11);
                  } else if (i == 2) {
                    _navigate(4);
                  } else if (i == 3) {
                    _navigate(9);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        color: selected ? _accentBlue : _textSecondary,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? _accentBlue : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.only(left: 4, right: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _statusLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_activeTrip != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentGreen.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Activo',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_statusLoading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          else
            Switch(
              value: _online,
              onChanged: (_) => _toggleStatus(),
              activeThumbColor: Colors.white,
              activeTrackColor: _accentBlue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white24,
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTripCard() {
    final t = _activeTrip!;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final nombre = cliente?['nombre'] as String? ?? 'Cliente';
    final estado = t['estado'] as String? ?? '';
    final estadoLabel = estado == 'aceptado' ? 'Aceptado' : 'En curso';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A3C6E), Color(0xFF1565C0)]),
              borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _accentGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.trip_origin, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(estadoLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const Spacer(),
                  Text('ID: ${t['id']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  const Icon(Icons.person, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 16),
                _buildRouteRow(Icons.circle_outlined, 'Salida', origen?['direccion'] as String? ?? ''),
                const SizedBox(height: 10),
                _buildRouteRow(Icons.location_on_outlined, 'Llegada', destino?['direccion'] as String? ?? ''),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripInProgressScreen(trip: t))),
                    icon: const Icon(Icons.map_rounded, size: 22),
                    label: const Text('Ver viaje en el mapa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
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

  Widget _buildRouteRow(IconData icon, String label, String address) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.white60),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(address, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    ]);
  }

  Widget _buildHomeContent() {
    if (_activeTrip != null) {
      return _buildActiveTripCard();
    }
    final sinConductor = _profile?['conductor'] == null;
    final noVerificado = _verificacionEstado == 'rechazado' || _verificacionEstado == 'pendiente';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sinConductor)
            GestureDetector(
              onTap: () => _navigate(10),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_add_alt_1, size: 40, color: Colors.blue.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'Completa tu registro como conductor',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D47A1)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca para ir a Documentación',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
            )
          else if (noVerificado)
            GestureDetector(
              onTap: () => _navigate(10),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.verified_outlined, size: 40, color: Colors.orange.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'Debes completar la verificación',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca para ir a Documentación',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                    ),
                  ],
                ),
              ),
            ),
          Center(
            child: Text(
              'Viajes disponibles',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildWaitingCard(),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              children: [
                const Text(
                  'Esperando solicitudes...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Te notificaremos cuando\nhaya un nuevo envío.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: SizedBox(
              height: 260,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 260),
                    painter: _MockMapPainter(),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _accentBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: _accentBlue.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accentBlue.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

class _MockMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE8F0E9),
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final minorRoadPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final blockPaint = Paint()..color = const Color(0xFFD4E6D5);

    final blocks = [
      Rect.fromLTWH(10, 20, 100, 70),
      Rect.fromLTWH(130, 20, 80, 70),
      Rect.fromLTWH(230, 20, 110, 70),
      Rect.fromLTWH(10, 120, 100, 60),
      Rect.fromLTWH(130, 120, 80, 60),
      Rect.fromLTWH(230, 120, 110, 60),
      Rect.fromLTWH(10, 210, 100, 50),
      Rect.fromLTWH(130, 210, 80, 50),
      Rect.fromLTWH(230, 210, 110, 50),
    ];

    for (final block in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, const Radius.circular(4)),
        blockPaint,
      );
    }

    for (double y in [105.0, 195.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    canvas.drawLine(Offset(0, 15), Offset(size.width, 15), minorRoadPaint);

    for (double x in [120.0, 220.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    canvas.drawLine(Offset(5, 0), Offset(5, size.height), minorRoadPaint);
    canvas.drawLine(Offset(size.width - 5, 0), Offset(size.width - 5, size.height), minorRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
