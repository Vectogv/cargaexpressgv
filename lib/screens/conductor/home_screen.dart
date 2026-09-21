import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../contracts/trip_status.dart';
import '../../contracts/socket_events.dart';
import '../../widgets/carga_express_bottom_nav.dart';
import '../../widgets/solicitud_viaje_sheet.dart';
import '../../models/trip.dart';
import '../../services/api_client.dart';
import '../../services/cache_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service_client.dart';
import '../../services/driver_location_service.dart';
import '../../services/api/driver_service.dart';
import '../../services/map_config.dart';
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
  Map<String, dynamic>? _stats;
  Timer? _uiTimer;

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
      } else if (tipo == SocketEvents.tripStatusChanged) {
        final estado = event['estado'] as String?;
        if (estado == TripStatus.esperaConfirmacion || estado == TripStatus.finalizado || estado == TripStatus.cancelado) {
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
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await _fetchProfileFirst();
    final cachedTrip = CacheService.instance.getCachedActiveTrip();
    if (cachedTrip != null) {
      final estado = cachedTrip['estado'] as String?;
      if (estado == TripStatus.aceptado || estado == TripStatus.enCamino || estado == TripStatus.llegada || estado == TripStatus.enCurso || estado == TripStatus.entregado || estado == TripStatus.esperaConfirmacion || estado == TripStatus.pendienteConfirmacion) {
        if (mounted) setState(() => _activeTrip = cachedTrip);
        _redirectToActiveTrip();
        return;
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
    // Evitar apilar varias TripInProgressScreen: si ya hay otra pantalla
    // encima (p.ej. el propio viaje abierto), no volver a hacer push.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ModalRoute.of(context);
      if (current != null && !current.isCurrent) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => TripInProgressScreen(trip: _activeTrip != null ? Trip.fromJson(_activeTrip!) : null)));
    });
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (trip != null) {
        final estado = trip['estado'] as String?;
        final activeStates = [TripStatus.aceptado, TripStatus.enCamino, TripStatus.llegada, TripStatus.enCurso, TripStatus.entregado, TripStatus.esperaConfirmacion, TripStatus.pendienteConfirmacion];
        if (activeStates.contains(estado)) {
          CacheService.instance.cacheActiveTrip(trip);
          if (mounted) setState(() => _activeTrip = trip);
          return;
        }
      }
      CacheService.instance.clearActiveTrip();
    } catch (_) {
      CacheService.instance.clearActiveTrip();
    }
    if (mounted) {
      setState(() => _activeTrip = null);
    }
  }

  Future<void> _fetchProfileFirst() async {
    try {
      final profile = await ApiClient.instance.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
    }
    unawaited(_loadStats());
    // Refresca el mapa (posición del conductor) y el resumen mientras la pantalla está abierta.
    _uiTimer ??= Timer.periodic(const Duration(seconds: 20), (t) {
      if (!mounted) return;
      if (t.tick % 3 == 0) unawaited(_loadStats());
      setState(() {});
    });
  }

  Future<void> _loadStats() async {
    try {
      final stats = await DriverService.getTodayStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _toggleStatus() async {
    if (mounted) setState(() => _statusLoading = true);
    try {
      if (!_online) {
        // Verificar estado primero
        final estado = _verificacionEstado;
        if (estado == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cargando tu perfil... intenta en un momento'), backgroundColor: Colors.orange),
          );
          }
          return;
        }
        if (estado != 'aprobado') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tu cuenta no está aprobada para recibir viajes'), backgroundColor: Colors.orange),
          );
          }
          return;
        }
        // Intentar GPS primero
        final gpsOk = await DriverLocationService.instance.start();
        if (!gpsOk) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado. Actívalo en Ajustes.'), backgroundColor: Colors.red),
          );
          }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
      }
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  void _showNewTripBanner(Map<String, dynamic> event) {
    if (!mounted) return;
    // Payload mínimo por socket: {tripId, origen: string, precioEstimado, type}
    // Payload completo (polling cercanos): {id/_id, origen: {direccion,..}, precioEstimado, ...}
    final tripId = (event['tripId'] ?? event['id'] ?? event['_id'])?.toString();
    if (tripId == null || tripId.isEmpty) return;
    if (_activeBannerIds.contains(tripId)) return; // deduplicar
    _activeBannerIds.add(tripId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SolicitudViajeSheet(
        tripId: tripId,
        resumen: event,
        conductorLat: DriverLocationService.instance.lastLat,
        conductorLng: DriverLocationService.instance.lastLng,
        onVer: () {
          _offeredTripIds.add(tripId); // antes de navegar
          _resetNearbyNotificationState();
          _openTripDetail(tripId);
        },
      ),
    ).whenComplete(() => _activeBannerIds.remove(tripId));
  }

  Future<void> _openTripDetail(String tripId) async {
    if (!mounted) return;
    try {
      final detail = await ApiClient.instance.getTripDetail(tripId);
      if (!mounted) return;
      final estado = detail['estado'] as String?;
      if (estado != null && estado != TripStatus.buscando
          && estado != 'pendiente') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este viaje ya no está disponible')),
        );
        return;
      }
      final tripData = Map<String, dynamic>.from(detail);
      if (tripData['id'] == null) tripData['id'] = tripId;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ConductorTripDetailScreen(trip: tripData),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el viaje: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
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
      1: TripInProgressScreen(trip: _activeTrip != null ? Trip.fromJson(_activeTrip!) : null),
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
      bottomNavigationBar: CargaExpressBottomNav(
        currentIndex: _bottomIndex,
        items: [
          (icon: Icons.home_rounded, label: 'Inicio', onTap: () {
            setState(() => _bottomIndex = 0);
          }),
          (icon: Icons.receipt_long_rounded, label: 'Viajes', onTap: () {
            _navigate(11);
          }),
          (icon: Icons.bar_chart_rounded, label: 'Ingresos', onTap: () {
            _navigate(4);
          }),
          (icon: Icons.person_rounded, label: 'Perfil', onTap: () {
            _navigate(9);
          }),
        ],
      ),
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

  Widget _buildHeader() {
    final nombre = (_profile?['nombre'] as String?)?.trim();
    final saludo = (nombre == null || nombre.isEmpty) ? 'Hola, conductor' : 'Hola, ${nombre.split(' ').first}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryBlue, _accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      _initials(nombre),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(saludo,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        Text(_statusLabel(),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_activeTrip != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentGreen.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Viaje activo',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildOnlineToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _online ? const Color(0xFF4ADE80) : Colors.white38,
              boxShadow: _online
                  ? [BoxShadow(color: const Color(0xFF4ADE80).withValues(alpha: 0.6), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_online ? 'Conectado' : 'Desconectado',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(_online ? 'Recibiendo solicitudes cercanas' : 'No recibirás solicitudes',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
              ],
            ),
          ),
          if (_statusLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            Switch(
              value: _online,
              onChanged: (_) => _toggleStatus(),
              activeThumbColor: Colors.white,
              activeTrackColor: _accentGreen,
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
    String estadoLabel;
    switch (estado) {
      case TripStatus.aceptado: estadoLabel = 'Aceptado'; break;
      case TripStatus.enCamino: estadoLabel = 'En camino'; break;
      case TripStatus.llegada: estadoLabel = 'Llegada al origen'; break;
      case TripStatus.enCurso: estadoLabel = 'En curso'; break;
      case TripStatus.entregado: estadoLabel = 'Entregado'; break;
      case TripStatus.esperaConfirmacion: estadoLabel = 'Esperando confirmación'; break;
      case TripStatus.pendienteConfirmacion: estadoLabel = 'Esperando confirmación del cliente'; break;
      case TripStatus.reservado: estadoLabel = 'Reservado'; break;
      default: estadoLabel = 'Activo';
    }

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
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripInProgressScreen(trip: Trip.fromJson(t)))),
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
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildMapCard(),
          const SizedBox(height: 16),
          _buildWaitingCard(),
          const SizedBox(height: 20),
          const Text('Accesos rápidos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 10),
          _buildQuickActions(),
        ],
      ),
    );
  }

  num? _num(dynamic v) => v == null ? null : num.tryParse(v.toString());

  String _money(num? v) {
    if (v == null) return '\$ 0';
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '\$ $b';
  }

  Widget _buildStatsRow() {
    final rating = _num(_stats?['calificacion']);
    return Row(
      children: [
        _statTile(Icons.payments_rounded, 'Hoy', _money(_num(_stats?['netaHoy'])), const Color(0xFF16A34A)),
        const SizedBox(width: 10),
        _statTile(Icons.local_shipping_rounded, 'Viajes hoy', '${_num(_stats?['viajesHoy'])?.toInt() ?? 0}', _accentBlue),
        const SizedBox(width: 10),
        _statTile(Icons.star_rounded, 'Calificación',
            rating == null || rating == 0 ? '—' : rating.toStringAsFixed(1), const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    final lat = DriverLocationService.instance.lastLat;
    final lng = DriverLocationService.instance.lastLng;
    final tienePosicion = lat != null && lng != null;
    // Sin posición aún: centro de Cali como referencia.
    final centro = tienePosicion ? LatLng(lat, lng) : const LatLng(3.4516, -76.5320);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('${centro.latitude},${centro.longitude}'),
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
              ),
              children: [
                TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app'),
                if (tienePosicion)
                  MarkerLayer(markers: [
                    Marker(
                      point: centro,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _accentBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: _accentBlue.withValues(alpha: 0.45), blurRadius: 12, spreadRadius: 3)],
                        ),
                        child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
              ],
            ),
            if (!_online)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  child: const Text('Conéctate para recibir viajes cerca de ti',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _textDark)),
                ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(tienePosicion ? Icons.my_location : Icons.location_searching, size: 14, color: _accentBlue),
                  const SizedBox(width: 6),
                  Text(tienePosicion ? 'Tu ubicación' : 'Buscando tu ubicación...',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingCard() {
    final online = _online;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: (online ? _accentBlue : _textGrey).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(online ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                color: online ? _accentBlue : _textGrey, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(online ? 'Esperando solicitudes' : 'Estás desconectado',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 4),
                Text(
                  online
                      ? 'Te avisaremos al instante cuando haya un envío cerca de ti.'
                      : 'Conéctate para empezar a recibir envíos.',
                  style: const TextStyle(fontSize: 13, color: _textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          if (!online) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _statusLoading ? null : _toggleStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Conectarme'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final acciones = [
      (Icons.receipt_long_rounded, 'Mis viajes', 11, const Color(0xFF2563EB)),
      (Icons.bar_chart_rounded, 'Ingresos', 4, const Color(0xFF16A34A)),
      (Icons.description_rounded, 'Documentos', 10, const Color(0xFFF59E0B)),
      (Icons.person_rounded, 'Perfil', 9, const Color(0xFF7C3AED)),
    ];
    return Row(
      children: [
        for (var i = 0; i < acciones.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _navigate(acciones[i].$3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Icon(acciones[i].$1, color: acciones[i].$4, size: 26),
                      const SizedBox(height: 6),
                      Text(acciones[i].$2,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}
