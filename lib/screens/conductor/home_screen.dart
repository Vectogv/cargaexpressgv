import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../services/driver_location_service.dart';
import '../user/auth_screen.dart';
import 'trip_in_progress_screen.dart';
import 'offers_screen.dart';
import 'earnings_screen.dart';
import 'trip_chat_screen.dart';
import 'notifications_screen.dart';
import 'surveys_screen.dart';
import 'profile_screen.dart';
import 'documents_screen.dart';
import 'forum_screen.dart';
import 'sos_alert_screen.dart';
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
  List<Map<String, dynamic>> _nearbyTrips = [];
  bool _loadingTrips = true;
  bool _online = true;
  bool _statusLoading = false;

  Map<String, dynamic>? _earnings;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _commission;

  StreamSubscription<List<Map<String, dynamic>>>? _tripSub;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchData();

    _socketSub = NotificationService.instance.onNotification.listen((event) {
      final tipo = event['__event'] as String?;
      if (tipo == 'trip:nearby') {
        _showNewTripBanner(event);
        _fetchNearbyTrips();
      } else if (tipo == 'trip:accepted') {
        final tripId = event['tripId'] ?? event['id'];
        if (tripId != null) {
          DriverLocationService.instance.removeTrip(tripId);
        }
        _fetchNearbyTrips();
      }
    });

    _tripSub = DriverLocationService.instance.onTripsUpdated.listen((trips) {
      if (mounted) setState(() { _nearbyTrips = trips; _loadingTrips = false; });
    });
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await _fetchProfileFirst();
    await Future.wait([
      _fetchStats(),
    ]);
    if (_online && _verificacionEstado == 'aprobado') {
      await DriverLocationService.instance.start();
    }
    await _fetchNearbyTrips();
  }

  Future<void> _fetchProfileFirst() async {
    try {
      final profile = await ApiClient.instance.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Future<void> _fetchNearbyTrips() async {
    if (_verificacionEstado != 'aprobado') {
      if (mounted) setState(() => _loadingTrips = false);
      return;
    }
    if (DriverLocationService.instance.lastLat != null && DriverLocationService.instance.lastLng != null) {
      try {
        final trips = await ApiClient.instance.getNearbyTrips(
          DriverLocationService.instance.lastLat!,
          DriverLocationService.instance.lastLng!,
          radio: 20,
        );
        if (mounted) setState(() { _nearbyTrips = trips; _loadingTrips = false; });
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingTrips = false);
  }

  Future<void> _fetchStats() async {
    try {
      final results = await Future.wait([
        ApiClient.instance.getEarnings(),
        ApiClient.instance.getDriverStats(),
        ApiClient.instance.getDebt(),
      ]);
      if (mounted) setState(() {
        _earnings = results[0];
        _stats = results[1];
        _commission = results[2];
      });
    } catch (_) {}
  }

  Future<void> _toggleStatus() async {
    setState(() => _statusLoading = true);
    try {
      await ApiClient.instance.setDriverStatus(!_online);
      if (mounted) {
        setState(() => _online = !_online);
        if (_online) {
          await DriverLocationService.instance.start();
          _fetchNearbyTrips();
        } else {
          DriverLocationService.instance.pause();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')));
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  void _showNewTripBanner(Map<String, dynamic> event) {
    if (!mounted) return;
    final origen = event['origen'] as String? ?? 'tu zona';
    final precio = event['precio'] ?? event['precioEstimado'];
    final msg = 'Nuevo viaje disponible cerca de $origen${precio != null ? ' \u2014 \$${precio}' : ''}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.local_shipping, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.yellow,
          onPressed: () => _scrollToTrips(),
        ),
      ),
    );
  }

  void _scrollToTrips() {}

  String? get _verificacionEstado {
    final conductor = _profile?['conductor'] as Map<String, dynamic>?;
    return conductor?['estadoVerificacion'] as String?;
  }

  bool get _tieneDocsFaltantes {
    final conductor = _profile?['conductor'] as Map<String, dynamic>?;
    if (conductor == null) return false;
    final campos = ['fotoCedula', 'fotoLicencia', 'fotoVehiculo', 'fotoConductor'];
    for (final c in campos) {
      final val = conductor[c] as String?;
      if (val == null || val.isEmpty) return true;
    }
    return false;
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

  IconData _statusIcon() {
    final estado = _verificacionEstado;
    if (estado == 'rechazado' || estado == 'pendiente') return Icons.verified_outlined;
    if (!_online) return Icons.cloud_off;
    return Icons.verified;
  }

  void _navigate(int index) {
    final routes = <int, Widget>{
      1: const TripInProgressScreen(),
      2: const OffersScreen(),
      4: const EarningsScreen(),
      5: TripChatScreen(trip: null),
      6: const NotificationsScreen(),
      7: const ForumScreen(),
      8: const SurveysScreen(),
      9: const ProfileScreen(),
      10: const DocumentsScreen(),
      11: const TripHistoryScreen(),
      12: const SupportScreen(),
      13: const SettingsScreen(),
    };
    final route = routes[index];
    if (route != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => route));
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
            child: IndexedStack(
              index: _bottomIndex,
              children: [
                _buildHomeContent(),
                const ForumScreen(),
                const SurveysScreen(),
                const EarningsScreen(),
                const SizedBox(),
              ],
            ),
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
                  backgroundColor: _white.withOpacity(0.2),
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
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) {
          if (i == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SOSAlertScreen()));
          } else {
            setState(() => _bottomIndex = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: _white,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: _textGrey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Foro'),
          BottomNavigationBarItem(icon: Icon(Icons.poll_outlined), label: 'Encuestas'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on_outlined), label: 'Ganancias'),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.sos, color: Colors.red.shade700, size: 22),
            ),
            label: 'SOS',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 8, right: 12, bottom: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: _textDark, size: 24),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _primaryDark, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buenos d\u00edas, ${ApiClient.instance.nombre ?? ''}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark),
                ),
                GestureDetector(
                  onTap: _tieneDocsFaltantes || _verificacionEstado == 'rechazado' || _verificacionEstado == 'pendiente'
                      ? () => _navigate(10)
                      : null,
                  child: Row(
                    children: [
                      Icon(_statusIcon(), color: _statusColor(), size: 11),
                      const SizedBox(width: 3),
                      Text(
                        _statusLabel(),
                        style: TextStyle(fontSize: 10, color: _statusColor(), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: _textDark, size: 24),
                onPressed: () => _navigate(6),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusToggle(),
          const SizedBox(height: 16),
          _buildMainCards(),
          const SizedBox(height: 20),
          _buildAvailableTrips(),
        ],
      ),
    );
  }

  Widget _buildStatusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: _online ? _accentGreen : Colors.grey, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_online ? 'En l\u00ednea' : 'Fuera de l\u00ednea', style: const TextStyle(fontWeight: FontWeight.w600))),
          _statusLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: _online,
                  onChanged: (_) => _toggleStatus(),
                  activeColor: _accentGreen,
                ),
        ],
      ),
    );
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is Map) return (v['amount'] ?? v['monto'] ?? 0) as num;
    return 0;
  }

  Widget _buildMainCards() {
    final gananciaHoy = _toNum(_earnings?['hoy']);
    final viajesHoy = _toNum(_stats?['viajesHoy']);
    final viajesTotal = _toNum(_stats?['viajes']);
    final calificacion = _toNum(_stats?['calificacion']);
    final comision = _toNum(_commission?['monto'] ?? _commission?['deuda']);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.monetization_on_outlined, '\$${_fmtAmount(gananciaHoy)}', 'Ganancias del d\u00eda', const Color(0xFFE8F5E9), const Color(0xFF2E7D32))),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard(Icons.route_outlined, '$viajesHoy', 'Viajes hoy', const Color(0xFFE3F2FD), const Color(0xFF1565C0))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildStatCard(Icons.assignment_turned_in_outlined, '$viajesTotal', 'Total completados', const Color(0xFFFFF8E1), const Color(0xFFFF8F00))),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard(Icons.star_rounded, calificacion.toStringAsFixed(1), 'Calificaci\u00f3n', const Color(0xFFF3E5F5), const Color(0xFF6A1B9A))),
          ],
        ),
        const SizedBox(height: 8),
        _buildCommissionCard(comision),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8.5, color: _textGrey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCommissionCard(num comision) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.account_balance_wallet_outlined, color: Colors.red.shade700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Deuda pendiente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text('\$${_fmtAmount(comision)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.red.shade700)),
        ],
      ),
    );
  }

  Widget _buildAvailableTrips() {
    final estado = _verificacionEstado;
    final verificado = estado == 'aprobado';
    final sinConductor = _profile?['conductor'] == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Viajes disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
        const SizedBox(height: 12),
        if (sinConductor)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.blue.shade200)),
            child: Column(
              children: [
                Icon(Icons.person_add_alt_1, size: 40, color: Colors.blue.shade400),
                const SizedBox(height: 10),
                const Text('Completa tu registro como conductor', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                const SizedBox(height: 4),
                Text('Toca para ir a Documentaci\u00f3n', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
              ],
            ),
          )
        else if (!verificado)
          GestureDetector(
            onTap: () => _navigate(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.shade200)),
              child: Column(
                children: [
                  Icon(Icons.verified_outlined, size: 40, color: Colors.orange.shade400),
                  const SizedBox(height: 10),
                  const Text('Debes completar la verificaci\u00f3n', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
                  const SizedBox(height: 4),
                  Text('Toca para ir a Documentaci\u00f3n', style: TextStyle(fontSize: 13, color: Colors.orange.shade700)),
                ],
              ),
            ),
          )
        else if (_loadingTrips)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_nearbyTrips.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('No hay viajes disponibles cerca', style: TextStyle(color: Colors.black45))),
          )
        else
          ..._nearbyTrips.take(10).map((t) => _buildTripCard(t)),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> t) {
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final precio = t['precioEstimado'] as num?;
    final distancia = t['distancia'] as num?;
    final carga = t['carga'] as String? ?? 'No especificada';
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final descripcion = t['descripcion'] as String? ?? cliente?['nombre'] as String? ?? '';
    final tiempo = t['tiempoEstimado'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
      ]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('${_fmtDate(t['createdAt'] as String?)}', style: TextStyle(fontSize: 11, color: _primaryBlue, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('${distancia?.toStringAsFixed(1) ?? '?'} km', style: TextStyle(color: _accentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _accentGreen, shape: BoxShape.circle, border: Border.all(color: _white, width: 2), boxShadow: [BoxShadow(color: _accentGreen.withOpacity(0.4), blurRadius: 4)])),
                Container(width: 2, height: 30, color: _textGrey.withOpacity(0.3), margin: const EdgeInsets.symmetric(vertical: 3)),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: _white, width: 2), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 4)])),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(origen?['direccion'] as String? ?? 'Origen', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 14),
                Text(destino?['direccion'] as String? ?? 'Destino', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
              ])),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.inventory_2_outlined, size: 16, color: _textGrey),
              const SizedBox(width: 6),
              Expanded(child: Text('Tipo: $carga', style: TextStyle(fontSize: 12, color: _textGrey))),
            ]),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.description_outlined, size: 16, color: _textGrey),
                const SizedBox(width: 6),
                Expanded(child: Text(descripcion, style: TextStyle(fontSize: 12, color: _textGrey), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('\$${precio?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
                  const Text('Precio ofrecido', style: TextStyle(fontSize: 10, color: _textGrey)),
                ]),
                if (tiempo != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$tiempo min', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textGrey)),
                    const Text('Tiempo estimado', style: TextStyle(fontSize: 10, color: _textGrey)),
                  ]),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Ver ruta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryDark,
                      side: BorderSide(color: _primaryDark.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      DriverLocationService.instance.removeTrip(t['id']);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ConductorTripDetailScreen(trip: t)));
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Enviar oferta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark,
                      foregroundColor: _white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtAmount(num amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}
