import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'trip_history_screen.dart';
import '../services/trip_service.dart';
import '../services/driver_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

enum _DriverState { offline, online, tripRequest, onTrip, enCurso }

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapCtrl = MapController();
  final _api = ApiClient();
  final _tripService = TripService();
  final _driverService = DriverService();

  _DriverState _state = _DriverState.offline;
  int _trips = 0;
  double _earnings = 0;
  double _hoursOnline = 0;
  double _kmToday = 0;
  int _tripCountToday = 0;
  double _calificacion = 4.9;
  String _driverName = 'Conductor';
  String _driverInitials = 'C';
  String? _avatarUrl;

  late AnimationController _pulseCtrl;

  Timer? _onlineTimer;
  Timer? _gpsTimer;
  Timer? _pollTripTimer;
  StreamSubscription<Position>? _gpsSubscription;
  LatLng? _lastGpsPos;
  int _countdown = 20;

  String? _currentTripId;
  String _currentRequestTipoCarga = 'Mercancía';
  String _currentRequestCarga = 'Carga';
  String _currentRequestOrigen = 'Dirección de recogida';
  String _currentRequestDestino = 'Dirección de destino';
  double _currentRequestLat = 10.4850;
  double _currentRequestLng = -66.8980;
  double _currentRequestPrecio = 35.0;

  bool _cargaAsegurada = false;
  bool _fotoEvidencia = false;
  bool _clienteNotificado = false;
  bool _entregaConfirmada = false;

  static const _defaultPos = LatLng(10.4806, -66.9036);
  LatLng _driverPos = _defaultPos;
  final List<LatLng> _routePoints = [];
  bool _showRoute = false;

  final _vehicleInfo = _VehicleInfo(
    type: 'Camioneta',
    plate: '---',
    capacity: '---',
  );

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initData();
  }

  Future<void> _initData() async {
    try {
      final profile = await _api.get('/users/profile');
      final nombre = profile['nombre'] ?? '';
      final apellido = profile['apellido'] ?? '';
      _driverName = '$nombre $apellido'.trim();
      _driverInitials = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C';
      _avatarUrl = profile['avatar'] as String?;

      if (profile['conductor'] != null) {
        final c = profile['conductor'] as Map<String, dynamic>;
        _vehicleInfo.type = (c['tipoVehiculo'] as String?) ?? 'Camioneta';
        _vehicleInfo.plate = (c['placa'] as String?) ?? '---';
        _vehicleInfo.capacity = (c['capacidad'] as String?) ?? '---';
      }

      final active = await _tripService.getActiveTrip();
      if (active != null) {
        _currentTripId = active.id;
        _currentRequestOrigen = active.origenDireccion;
        _currentRequestDestino = active.destinoDireccion;
        _currentRequestLat = active.origenLat;
        _currentRequestLng = active.origenLng;
        _currentRequestCarga = active.carga ?? 'Carga';
        _currentRequestPrecio = active.precioEstimado ?? 35.0;
        if (active.estado == 'aceptado') {
          setState(() => _state = _DriverState.onTrip);
        } else if (active.estado == 'en_curso') {
          setState(() => _state = _DriverState.enCurso);
        } else {
          setState(() => _state = _DriverState.online);
        }
      } else {
        try {
          await _driverService.setStatus(true);
        } catch (_) {}
        setState(() => _state = _DriverState.online);
        _startOnlineTimer();
        _startGpsTracking();
        _pollForTrips();
      }

      await _loadStats();
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _driverService.getStats();
      final earnings = await _driverService.getEarnings();
      final today = await _driverService.getTodayStats();
      setState(() {
        _trips = stats.viajes;
        _hoursOnline = stats.horasActivo;
        _calificacion = stats.calificacion;
        _earnings = today['gananciasHoy']?.toDouble() ?? earnings.hoy;
        _tripCountToday = today['viajesHoy'] ?? stats.viajes;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _onlineTimer?.cancel();
    _gpsTimer?.cancel();
    _gpsSubscription?.cancel();
    _pollTripTimer?.cancel();
    super.dispose();
  }

  double _distanceTo(double lat, double lng) {
    final diff = const Distance().as(LengthUnit.Meter, _driverPos, LatLng(lat, lng));
    return (diff / 1000);
  }

  Future<void> _toggleOnline() async {
    if (_state == _DriverState.offline) {
      try {
        await _driverService.setStatus(true);
      } catch (_) {}
      setState(() => _state = _DriverState.online);
      _pulseCtrl.repeat(reverse: true);
      _startOnlineTimer();
      _startGpsTracking();
      _pollForTrips();
    } else if (_state == _DriverState.online) {
      try {
        await _driverService.setStatus(false);
      } catch (_) {}
      setState(() => _state = _DriverState.offline);
    _pulseCtrl.reset();
    _onlineTimer?.cancel();
      _gpsTimer?.cancel();
      _gpsSubscription?.cancel();
      _pollTripTimer?.cancel();
    }
  }

  void _startOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted && (_state == _DriverState.online || _state == _DriverState.onTrip || _state == _DriverState.enCurso)) {
        setState(() => _hoursOnline += 0.5);
      }
    });
  }

  void _startGpsTracking() async {
    _gpsSubscription?.cancel();
    _lastGpsPos = null;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        _gpsSubscription = Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position pos) async {
          if (!mounted || _state == _DriverState.offline) return;
          final newPos = LatLng(pos.latitude, pos.longitude);
          if (_lastGpsPos != null) {
            final dist = const Distance().as(LengthUnit.Meter, _lastGpsPos!, newPos);
            _kmToday += (dist / 1000);
          }
          _lastGpsPos = newPos;
          try {
            await _driverService.updateLocation(pos.latitude, pos.longitude);
          } catch (_) {}
          setState(() {
            _driverPos = newPos;
            _routePoints.add(newPos);
            if (_routePoints.length > 500) _routePoints.removeAt(0);
          });
        });
      }
    } catch (_) {}
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      if (!mounted || _state == _DriverState.offline || _lastGpsPos == null) return;
      try {
        await _driverService.updateLocation(
          _lastGpsPos!.latitude, _lastGpsPos!.longitude,
        );
      } catch (_) {}
    });
  }

  void _pollForTrips() {
    _pollTripTimer?.cancel();
    _pollTripTimer = Timer.periodic(Duration(seconds: 8), (_) async {
      if (!mounted || _state != _DriverState.online) return;
      try {
        final nearby = await _tripService.getNearby(
          lat: _driverPos.latitude,
          lng: _driverPos.longitude,
          radio: 10,
        );
        if (nearby.isNotEmpty) {
          final t = nearby.first;
          _currentTripId = t.id;
          _currentRequestTipoCarga = t.carga ?? 'Mercancía';
          _currentRequestCarga = t.carga ?? 'Carga';
          _currentRequestPrecio = t.precioEstimado ?? 35.0;
          _currentRequestOrigen = t.origenDireccion;
          _currentRequestDestino = t.destinoDireccion;
          _currentRequestLat = t.origenLat;
          _currentRequestLng = t.origenLng;
          setState(() {
            _state = _DriverState.tripRequest;
            _countdown = 20;
          });
          _startCountdown();
          _pollTripTimer?.cancel();
        }
      } catch (_) {}
    });
  }

  void _startCountdown() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted || _state != _DriverState.tripRequest) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _declineTrip();
      }
    });
  }

  Future<void> _acceptTrip() async {
    if (_currentTripId == null) return;
    try {
      await _tripService.acceptTrip(_currentTripId!);
      setState(() {
        _state = _DriverState.onTrip;
      });
    } catch (_) {}
  }

  Future<void> _declineTrip() async {
    if (_currentTripId != null) {
      try {
        await _tripService.declineTrip(_currentTripId!);
      } catch (_) {}
    }
    _currentTripId = null;
    setState(() => _state = _DriverState.online);
    _pollForTrips();
  }

  Future<void> _startTrip() async {
    if (_currentTripId == null) return;
    try {
      await _tripService.startTrip(_currentTripId!);
      setState(() {
        _state = _DriverState.enCurso;
        _cargaAsegurada = false;
        _fotoEvidencia = false;
        _clienteNotificado = false;
        _entregaConfirmada = false;
      });
    } catch (_) {}
  }

  Future<void> _completeTrip() async {
    if (_currentTripId == null) return;
    final fare = 25 + Random().nextInt(40);
    try {
      await _tripService.finalizeTrip(_currentTripId!, montoFinal: fare.toDouble());
      await _loadStats();
      _currentTripId = null;
      setState(() {
        _trips++;
        _earnings += fare;
        _tripCountToday++;
        _state = _DriverState.online;
      });
      _pollForTrips();
    } catch (_) {}
  }

  void _logout() {
    AuthService().logout();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('userEmail');
      prefs.remove('userName');
    });
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  bool get _checklistComplete =>
      _cargaAsegurada && _fotoEvidencia && _clienteNotificado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildMap(),
          _buildKmOverlay(),
          _buildTopBar(),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildDrawerEarnings() {
    final avgPerTrip = _tripCountToday > 0 ? _earnings / _tripCountToday : 0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.monetization_on, size: 14, color: Colors.greenAccent),
              SizedBox(width: 6),
              Text('GANANCIAS',
                  style: TextStyle(
                      color: Colors.greenAccent, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              Spacer(),
              Text('\$${_earnings.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              _DrawerStat(label: 'Viajes', value: '$_tripCountToday'),
              _DrawerStat(label: 'Promedio', value: '\$${avgPerTrip.toStringAsFixed(0)}'),
              _DrawerStat(label: 'Km', value: '${_kmToday.toStringAsFixed(1)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Color(0xFF0A0A0A),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Color(0xFF1A8CFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Color(0xFF1A8CFF).withValues(alpha: 0.3),
                          width: 2),
                      image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(
                                  '${_api.baseUrl.replaceAll('/api', '')}$_avatarUrl'),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? Center(child: Text(_driverInitials,
                            style: TextStyle(color: Colors.white, fontSize: 18,
                                fontWeight: FontWeight.bold)))
                        : null,
                  ),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_driverName,
                          style: TextStyle(color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('Conductor',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),
              _buildDrawerEarnings(),
              SizedBox(height: 24),
              _DrawerItem(
                icon: Icons.person_outline_rounded,
                label: 'Perfil',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ));
                },
              ),
              _DrawerItem(
                icon: Icons.help_outline_rounded,
                label: 'Ayuda',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Configuración',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.history_rounded,
                label: 'Historial de viajes',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const TripHistoryScreen(),
                  ));
                },
              ),
              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                onTap: _logout,
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.emergency_rounded, size: 22),
                  label: Text('Llamada de emergencia',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: Color(0xFFE53935).withValues(alpha: 0.4),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _driverPos,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cargaexpress.app',
        ),
        if (_routePoints.length > 1 && _showRoute)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4,
                color: Color(0xFF1A8CFF).withValues(alpha: 0.6),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _driverPos,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: _state == _DriverState.offline
                      ? Colors.grey
                      : _state == _DriverState.onTrip || _state == _DriverState.enCurso
                          ? Colors.green
                          : Color(0xFF1A8CFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(
                      color: (_state == _DriverState.offline
                              ? Colors.grey
                              : _state == _DriverState.onTrip || _state == _DriverState.enCurso
                                  ? Colors.green
                                  : Color(0xFF1A8CFF))
                          .withValues(alpha: 0.5),
                      blurRadius: 10)],
                ),
                child: Icon(Icons.navigation, color: Colors.white, size: 18),
              ),
            ),
            if (_state == _DriverState.onTrip || _state == _DriverState.enCurso)
              Marker(
                point: LatLng(_currentRequestLat, _currentRequestLng),
                width: 100,
                height: 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Destino',
                          style: TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(height: 4),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6)],
                      ),
                      child: Icon(Icons.flag, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18,
            color: Colors.white.withValues(alpha: 0.35)),
        SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
            Text(value, style: TextStyle(
                color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w500)),
          ],
        )),
      ],
    );
  }

  Widget _buildKmOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showRoute = !_showRoute),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, size: 16, color: Color(0xFF1A8CFF)),
                  SizedBox(width: 6),
                  Text('${_kmToday.toStringAsFixed(1)} km',
                      style: TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          if (_routePoints.length > 1) ...[
            SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _showRoute = !_showRoute),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _showRoute
                      ? Color(0xFF1A8CFF).withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showRoute
                        ? Color(0xFF1A8CFF).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showRoute ? Icons.visibility : Icons.visibility_off,
                      size: 16,
                      color: _showRoute ? Color(0xFF1A8CFF) : Colors.white.withValues(alpha: 0.6),
                    ),
                    SizedBox(width: 6),
                    Text('Ruta',
                        style: TextStyle(
                            color: _showRoute ? Colors.white : Colors.white.withValues(alpha: 0.6),
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ganancias de hoy',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11, fontWeight: FontWeight.w500)),
                  Text('\$${_earnings.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Spacer(),
              _TopIcon(
                icon: Icons.notifications_outlined,
                badge: true,
              ),
              SizedBox(width: 8),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Color(0xFF1A8CFF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Color(0xFF1A8CFF).withValues(alpha: 0.3), width: 1.5),
                  image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(
                              '${_api.baseUrl.replaceAll('/api', '')}$_avatarUrl'),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: _avatarUrl == null || _avatarUrl!.isEmpty
                    ? Center(child: Text(_driverInitials,
                        style: TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.bold)))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _state == _DriverState.offline
            ? _buildOfflineCard()
            : _state == _DriverState.online
                ? _buildOnlineCard()
                : _state == _DriverState.tripRequest
                    ? _buildTripRequestCard()
                    : _state == _DriverState.onTrip
                        ? _buildOnTripCard()
                        : _buildEnCursoCard(),
      ),
    );
  }

  Widget _cardWrap(Widget child) {
    return Container(
      key: ValueKey(_state),
      decoration: BoxDecoration(
        color: Color(0xFF0D0D0D),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30, offset: Offset(0, -10))],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4))),
          SizedBox(height: 16),
          child,
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ]),
      ),
    );
  }

  Widget _buildOfflineCard() {
    return _cardWrap(Column(
      children: [
        SizedBox(height: 12),
        _buildEarningsSection(),
        SizedBox(height: 24),
        _buildStatsRow(),
        SizedBox(height: 8),
      ],
    ));
  }

  Widget _buildOnlineCard() {
    return _cardWrap(Column(
      children: [
        SizedBox(height: 12),
        _buildEarningsSection(),
        SizedBox(height: 24),
        _buildStatsRow(),
        SizedBox(height: 8),
      ],
    ));
  }

  bool _showEarningsDetail = false;

  Widget _buildEarningsSection() {
    final avgPerTrip = _tripCountToday > 0 ? _earnings / _tripCountToday : 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showEarningsDetail = !_showEarningsDetail),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, size: 16,
                      color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text('GANANCIAS',
                      style: TextStyle(
                          color: Colors.greenAccent, fontSize: 11,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Spacer(),
                  Text('\$${_earnings.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(
                    _showEarningsDetail
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.4), size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showEarningsDetail) ...[
            Container(height: 1, margin: EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withValues(alpha: 0.06)),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _EarningsDetail(label: 'Hoy', value: '\$${_earnings.toStringAsFixed(2)}'),
                      _EarningsDetail(label: 'Promedio/viaje', value: '\$${avgPerTrip.toStringAsFixed(2)}'),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _EarningsDetail(label: 'Viajes hoy', value: '$_tripCountToday'),
                      _EarningsDetail(label: 'Km recorridos', value: '${_kmToday.toStringAsFixed(1)} km'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripRequestCard() {
    return _cardWrap(Column(
      children: [
        SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('NUEVA SOLICITUD',
                  style: TextStyle(color: Colors.orange, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _countdown <= 5
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_countdown}s',
                  style: TextStyle(
                      color: _countdown <= 5
                          ? Colors.red
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Color(0xFFE53935).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.inventory_2, color: Color(0xFFE53935), size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentRequestTipoCarga,
                      style: TextStyle(color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  Text(_currentRequestCarga,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${_currentRequestPrecio.toStringAsFixed(0)}',
                    style: TextStyle(color: Color(0xFF1A8CFF), fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('${_distanceTo(_currentRequestLat, _currentRequestLng).toStringAsFixed(1)} km',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12)),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
        _infoRow(Icons.trip_origin, 'Dirección de recogida',
            _currentRequestOrigen),
        SizedBox(height: 12),
        _infoRow(Icons.location_on, 'Destino',
            _currentRequestDestino),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _declineTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Rechazar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _acceptTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1A8CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
                  ),
                  child: Text('Aceptar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
      ],
    ));
  }

  Widget _buildOnTripCard() {
    return _cardWrap(Column(
      children: [
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Color(0xFF1A8CFF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: Color(0xFF1A8CFF), shape: BoxShape.circle)),
              SizedBox(width: 6),
              Text('DIRÍGETE AL ORIGEN',
                  style: TextStyle(color: Color(0xFF1A8CFF), fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Color(0xFF1A8CFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.trip_origin, color: Color(0xFF1A8CFF), size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentRequestOrigen,
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text('Punto de recogida · ${_distanceTo(_currentRequestLat, _currentRequestLng).toStringAsFixed(1)} km',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildContactChip(Icons.phone_rounded, 'Llamar'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildContactChip(Icons.chat_rounded, 'Mensaje'),
            ),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _startTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A8CFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
            ),
            child: Text('Recoger carga',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        SizedBox(height: 8),
      ],
    ));
  }

  Widget _buildEnCursoCard() {
    return _cardWrap(Column(
      children: [
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              SizedBox(width: 6),
              Text('EN CURSO',
                  style: TextStyle(color: Colors.green, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.location_on, color: Colors.green, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentRequestDestino,
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text('Destino final',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHECKLIST DE ENTREGA',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11, fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              SizedBox(height: 14),
              _ChecklistItem(
                checked: _cargaAsegurada,
                label: 'Carga asegurada en vehículo',
                onToggle: () => setState(() =>
                    _cargaAsegurada = !_cargaAsegurada),
              ),
              SizedBox(height: 10),
              _ChecklistItem(
                checked: _fotoEvidencia,
                label: 'Foto evidencia de recogida',
                onToggle: () => setState(() =>
                    _fotoEvidencia = !_fotoEvidencia),
              ),
              SizedBox(height: 10),
              _ChecklistItem(
                checked: _clienteNotificado,
                label: 'Cliente notificado',
                onToggle: () => setState(() =>
                    _clienteNotificado = !_clienteNotificado),
              ),
              SizedBox(height: 10),
              _ChecklistItem(
                checked: _entregaConfirmada,
                label: 'Entrega confirmada',
                sublabel: 'Al llegar al destino',
                enabled: _checklistComplete && !_entregaConfirmada,
                onToggle: () => setState(() {
                  _entregaConfirmada = true;
                  _completeTrip();
                }),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
      ],
    ));
  }

  Widget _buildContactChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
          SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), fontSize: 14,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _toggleOnline,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: double.infinity, height: 72,
        decoration: BoxDecoration(
          color: _state != _DriverState.offline
              ? Color(0xFF1A8CFF)
              : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _state != _DriverState.offline
                ? Color(0xFF1A8CFF)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: _state != _DriverState.offline
              ? [BoxShadow(
                  color: Color(0xFF1A8CFF).withValues(alpha: 0.3),
                  blurRadius: 20, offset: Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: _state != _DriverState.offline
                    ? Colors.white
                    : Color(0xFF1A8CFF),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 14),
            AnimatedDefaultTextStyle(
              duration: Duration(milliseconds: 300),
              style: TextStyle(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w700, letterSpacing: 0.5,
              ),
              child: Text(
                  _state == _DriverState.onTrip || _state == _DriverState.enCurso
                      ? 'EN VIAJE'
                      : _state != _DriverState.offline
                          ? 'EN LÍNEA'
                          : 'FUERA DE LÍNEA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(children: [
      _StatTile(label: 'Viajes', value: '$_trips'),
      _buildDivider(),
      _StatTile(label: 'Horas activo', value: _hoursOnline.toStringAsFixed(1)),
      _buildDivider(),
      _StatTile(label: 'Calificación', value: _calificacion.toStringAsFixed(1)),
    ]);
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 36,
        color: Colors.white.withValues(alpha: 0.08));
  }
}

class _ChecklistItem extends StatelessWidget {
  final bool checked;
  final String label;
  final String? sublabel;
  final bool enabled;
  final VoidCallback onToggle;

  const _ChecklistItem({
    required this.checked,
    required this.label,
    this.sublabel,
    this.enabled = true,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onToggle : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: checked
              ? Colors.green.withValues(alpha: 0.08)
              : enabled
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked
                ? Colors.green.withValues(alpha: 0.2)
                : enabled
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: checked
                  ? Colors.green
                  : enabled
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.15),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: checked
                            ? Colors.green
                            : enabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                        fontWeight: checked
                            ? FontWeight.w600
                            : FontWeight.w500,
                        decoration: checked
                            ? TextDecoration.lineThrough
                            : null,
                      )),
                  if (sublabel != null)
                    Text(sublabel!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final bool badge;
  const _TopIcon({required this.icon, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(children: [
        Icon(icon, color: Colors.white, size: 22),
        if (badge)
          Positioned(top: 0, right: 0,
              child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: Color(0xFF1A8CFF), shape: BoxShape.circle))),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(color: Colors.white, fontSize: 22,
          fontWeight: FontWeight.bold)),
      SizedBox(height: 4),
      Text(label, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4), fontSize: 12,
          fontWeight: FontWeight.w500)),
    ]));
  }
}

class _VehicleInfo {
  String type;
  String plate;
  String capacity;
  _VehicleInfo({required this.type, required this.plate, required this.capacity});
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 22),
                SizedBox(width: 16),
                Text(label,
                    style: TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PanelStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Color(0xFF1A8CFF)),
        SizedBox(height: 6),
        Text(value,
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EarningsDetail extends StatelessWidget {
  final String label;
  final String value;
  const _EarningsDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DrawerStat extends StatelessWidget {
  final String label;
  final String value;
  const _DrawerStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 22),
        SizedBox(height: 6),
        Text(label, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5), fontSize: 12,
            fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
