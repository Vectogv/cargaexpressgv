import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'login_screen.dart';
import 'profile_screen.dart';
import 'trip_history_screen.dart';
import '../services/trip_service.dart';
import '../services/driver_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/dispute_service.dart';
import '../models/driver.dart';

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

  io.Socket? _socket;
  DriverEarnings? _driverEarnings;
  String? _clienteNombre;
  double? _clienteReputation;
  int _totalReportes = 0;
  bool _tripJustCompleted = false;
  bool _showOfertaEnviada = false;

  String _estadoVerificacion = 'aprobado';
  String? _motivoRechazo;

  String _statusCedula = 'pendiente';
  String _statusLicencia = 'pendiente';
  String _statusVehiculo = 'pendiente';

  String? _pathCedula;
  String? _pathLicencia;
  String? _pathVehiculo;
  String? _userId;

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
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');

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

      String storedVerif = prefs.getString('estadoVerificacion') ?? '';
      String? storedMotivo = prefs.getString('motivoRechazo');
      
      String verifStatus = 'aprobado';
      String? motivoRechazo;

      if (profile['conductor'] != null) {
        final c = profile['conductor'] as Map<String, dynamic>;
        verifStatus = c['estadoVerificacion'] ?? 'aprobado';
        motivoRechazo = c['motivoRechazo'] ?? c['notaAdmin'];
      }
      
      if (storedVerif.isNotEmpty) {
        verifStatus = storedVerif;
        if (storedMotivo != null) {
          motivoRechazo = storedMotivo;
        }
      }

      setState(() {
        _estadoVerificacion = verifStatus;
        _motivoRechazo = motivoRechazo;
      });

      if (verifStatus == 'pendiente' || verifStatus == 'rechazado') {
        _conectarSocketDriver();
        return;
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
        _driverEarnings = earnings;
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
    _socket?.disconnect();
    _socket?.dispose();
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
          _clienteNombre = t.cliente?['nombre'];
          _clienteReputation = (t.cliente?['reputacion'] as num?)?.toDouble();
          _totalReportes = t.cliente?['reportes'] ?? 0;
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

  String get _socketServerUrl {
    final base = _api.baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  void _conectarSocketDriver() {
    if (_userId == null) return;

    _socket?.disconnect();
    _socket?.dispose();

    _socket = io.io(_socketServerUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit('join:driver', _userId);
    });

    _socket!.on('offer:accepted', (data) {
      if (!mounted) return;
      setState(() => _state = _DriverState.onTrip);
    });

    _socket!.on('offer:rejected', (data) {
      if (!mounted) return;
      setState(() {
        _showOfertaEnviada = false;
        _state = _DriverState.online;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tu oferta no fue aceptada'),
          backgroundColor: Colors.orange,
        ),
      );
      _pollForTrips();
    });

    _socket!.on('driver:approved', (_) {
      if (!mounted) return;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('estadoVerificacion', 'aprobado');
      });
      setState(() {
        _estadoVerificacion = 'aprobado';
      });
      // Resume normal initialization
      _initData();
    });

    _socket!.on('driver:rejected', (data) {
      if (!mounted) return;
      final motivo = data != null && data is Map ? data['motivo'] : 'Documentos rechazados';
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('estadoVerificacion', 'rechazado');
        prefs.setString('motivoRechazo', motivo);
      });
      setState(() {
        _estadoVerificacion = 'rechazado';
        _motivoRechazo = motivo;
      });
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

  Future<void> _declineTrip() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (_currentTripId != null) {
      try {
        await _tripService.declineTrip(_currentTripId!);
      } catch (_) {}
    }
    _currentTripId = null;
    setState(() {
      _showOfertaEnviada = false;
      _state = _DriverState.online;
    });
    _pollForTrips();
  }

  void _showOfferSheet() {
    final precioCtrl = TextEditingController(
      text: _currentRequestPrecio.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4))),
              SizedBox(height: 20),
              Text('Tu oferta',
                  style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('El cliente ofrece \$${_currentRequestPrecio.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14)),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_money, size: 20, color: Colors.greenAccent),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: precioCtrl,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Tu precio',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final monto = double.tryParse(precioCtrl.text);
                    if (monto == null || monto <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ingresa un monto válido'),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _enviarOferta(monto);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1A8CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
                  ),
                  child: Text('Enviar oferta',
                      style: TextStyle(fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enviarOferta(double monto) async {
    if (_currentTripId == null) return;

    try {
      await _tripService.sendOffer(_currentTripId!, monto: monto);
      setState(() => _showOfertaEnviada = true);
      _conectarSocketDriver();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar oferta: $e'),
            backgroundColor: Colors.red),
      );
    }
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

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);

    if (file == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Subiendo foto de entrega...'), backgroundColor: Color(0xFF1A8CFF)),
    );

    try {
      await _api.upload('/trips/${_currentTripId}/delivery-photo', file.path, 'file');

      final fare = 25 + Random().nextInt(40);
      await _tripService.finalizeTrip(_currentTripId!, montoFinal: fare.toDouble());
      await _loadStats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      setState(() {
        _trips++;
        _earnings += fare;
        _tripCountToday++;
        _state = _DriverState.online;
        _tripJustCompleted = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al finalizar. Intenta de nuevo.'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTripCompletedCard() {
    return _cardWrap(Column(
      children: [
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
        ),
        SizedBox(height: 16),
        Text(
          '¡Viaje Completado!',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Has completado el envío con éxito.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _showReportClientDialog,
              icon: Icon(Icons.report_problem_rounded, size: 18),
              label: Text('Reportar cliente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showDisputeSheet,
              icon: Icon(Icons.money_off, size: 18),
              label: Text('Reportar no pago'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.15),
                foregroundColor: Colors.orangeAccent,
                side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _tripJustCompleted = false;
                _currentTripId = null;
              });
              _pollForTrips();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A8CFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: Text('Listo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(height: 8),
      ],
    ));
  }

  void _showReportClientDialog() {
    final reportCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text('Reportar Cliente', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas reportar a este cliente? Indica el motivo (ej. no pago, comportamiento inadecuado):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: reportCtrl,
              maxLines: 3,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Motivo del reporte...',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (reportCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Por favor indica un motivo'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);

              try {
                await _tripService.reportClient(_currentTripId!, reportCtrl.text);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reporte enviado con éxito. Gracias por ayudarnos a mantener segura la comunidad.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al enviar reporte: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text('Enviar Reporte', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showDisputeSheet() {
    final versionCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.money_off, color: Colors.orangeAccent, size: 22),
                  const SizedBox(width: 10),
                  const Text('Reportar no pago',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Describe tu versión de los hechos. El cliente podrá apelar.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: versionCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe lo sucedido...',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (versionCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor describe los hechos'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await DisputeService().reportDispute(_currentTripId!, versionCtrl.text);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tu reporte fue enviado. El cliente será notificado.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al enviar reporte: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Enviar reporte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEmergencyDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Row(
          children: [
            Icon(Icons.emergency_share, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Emergencia', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          '¿Confirmar emergencia? Se alertará al equipo de soporte',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _triggerEmergency();
    }
  }

  Future<void> _triggerEmergency() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 16),
            Text('Obteniendo ubicación...'),
          ],
        ),
        backgroundColor: Colors.redAccent,
      ),
    );

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      await _api.post('/emergency', body: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alerta enviada. El equipo fue notificado.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar alerta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    if (_estadoVerificacion == 'pendiente') {
      return _buildPendingVerificationScreen();
    } else if (_estadoVerificacion == 'rechazado') {
      return _buildRejectedVerificationScreen();
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildMap(),
          _buildKmOverlay(),
          _buildTopBar(),
          _buildBottomSheet(),
          if (_state == _DriverState.onTrip || _state == _DriverState.enCurso)
            Positioned(
              bottom: 340,
              right: 16,
              child: FloatingActionButton(
                onPressed: _showEmergencyDialog,
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingVerificationScreen() {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(),
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Color(0xFF1A8CFF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty_rounded,
                  color: Color(0xFF1A8CFF),
                  size: 64,
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Tu cuenta está siendo verificada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Estamos revisando tus documentos de conductor. Esto suele tardar menos de 24 horas.\n\nTe notificaremos por este medio en tiempo real cuando tu cuenta sea aprobada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1A8CFF)),
                ),
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: Icon(Icons.logout_rounded),
                  label: Text('Cerrar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedVerificationScreen() {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Center(
                child: Text(
                  'Verificación Rechazada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Center(
                child: Text(
                  'Por favor corrige los siguientes documentos para poder activar tu cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Motivo del rechazo:',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _motivoRechazo ?? 'Tus documentos no cumplen con los requisitos de legibilidad.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Re-subir Documentos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildHomeDocUploadButton(
                documentLabel: 'Cédula de Identidad',
                status: _statusCedula,
                filePath: _pathCedula,
                onTap: () => _pickHomeDocument('cedula'),
              ),
              SizedBox(height: 12),
              _buildHomeDocUploadButton(
                documentLabel: 'Licencia de Conducir',
                status: _statusLicencia,
                filePath: _pathLicencia,
                onTap: () => _pickHomeDocument('licencia'),
              ),
              SizedBox(height: 12),
              _buildHomeDocUploadButton(
                documentLabel: 'Foto del Vehículo',
                status: _statusVehiculo,
                filePath: _pathVehiculo,
                onTap: () => _pickHomeDocument('vehiculo'),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _enviarDocsDeNuevo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1A8CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
                  ),
                  child: Text(
                    'Enviar documentos de nuevo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: Icon(Icons.logout_rounded),
                  label: Text('Cerrar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeDocUploadButton({
    required String documentLabel,
    required String status,
    required String? filePath,
    required VoidCallback onTap,
  }) {
    Color borderColor;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'subido':
        borderColor = Colors.blue.withValues(alpha: 0.3);
        statusColor = Colors.blueAccent;
        statusText = 'Listo para enviar';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        borderColor = Colors.white.withValues(alpha: 0.1);
        statusColor = Colors.white.withValues(alpha: 0.35);
        statusText = 'Pendiente por subir';
        statusIcon = Icons.cloud_upload_outlined;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documentLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            if (filePath != null && status == 'subido')
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(filePath),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickHomeDocument(String docType) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file == null) return;

    setState(() {
      if (docType == 'cedula') {
        _pathCedula = file.path;
        _statusCedula = 'subido';
      } else if (docType == 'licencia') {
        _pathLicencia = file.path;
        _statusLicencia = 'subido';
      } else if (docType == 'vehiculo') {
        _pathVehiculo = file.path;
        _statusVehiculo = 'subido';
      }
    });
  }

  Future<void> _enviarDocsDeNuevo() async {
    if (_statusCedula != 'subido' && _statusLicencia != 'subido' && _statusVehiculo != 'subido') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor sube al menos un documento corregido para enviar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enviando documentos corregidos...'),
        backgroundColor: Color(0xFF1A8CFF),
      ),
    );

    await Future.delayed(Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('estadoVerificacion', 'pendiente');

    setState(() {
      _estadoVerificacion = 'pendiente';
      _statusCedula = 'pendiente';
      _statusLicencia = 'pendiente';
      _statusVehiculo = 'pendiente';
      _pathCedula = null;
      _pathLicencia = null;
      _pathVehiculo = null;
    });
  }

  bool _showFinanzas = false;

  Widget _buildDrawerEarnings() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showFinanzas = !_showFinanzas),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
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
                  SizedBox(width: 6),
                  Icon(
                    _showFinanzas ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.4), size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_showFinanzas) ...[
            Container(height: 1, margin: EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withValues(alpha: 0.06)),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildFinanzaCard('Hoy', _tripCountToday, _earnings),
                  SizedBox(height: 8),
                  _buildFinanzaCard('Esta semana', _driverEarnings?.viajesSemana ?? 0, _driverEarnings?.semana ?? 0),
                  SizedBox(height: 8),
                  _buildFinanzaCard('Este mes', _driverEarnings?.viajesMes ?? 0, _driverEarnings?.mes ?? 0),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text(
                          'Debes a la plataforma: \$${(_driverEarnings?.deuda ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanzaCard(String periodo, int viajes, double bruto) {
    final comision = bruto * 0.15;
    final neto = bruto - comision;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(periodo,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Spacer(),
              Text('$viajes viaje(s)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bruto',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
                    Text('\$${bruto.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comisión',
                        style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.6), fontSize: 10)),
                    Text('\$${comision.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Neto',
                        style: TextStyle(color: Colors.greenAccent.withValues(alpha: 0.6), fontSize: 10)),
                    Text('\$${neto.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
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
                ? (_tripJustCompleted ? _buildTripCompletedCard() : _buildOnlineCard())
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
    if (_showOfertaEnviada) {
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
                Text('OFERTA ENVIADA',
                    style: TextStyle(color: Color(0xFF1A8CFF), fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1)),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 72, height: 72,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Color(0xFF1A8CFF)),
            ),
          ),
          SizedBox(height: 16),
          Text('Tu oferta fue enviada',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w600)),
          Text('Esperando respuesta del cliente...',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13)),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                _socket?.disconnect();
                _socket?.dispose();
                _socket = null;
                setState(() {
                  _showOfertaEnviada = false;
                  _state = _DriverState.online;
                });
                _pollForTrips();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                elevation: 0,
              ),
              child: Text('Cancelar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(height: 8),
        ],
      ));
    }

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
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14,
                color: Colors.white.withValues(alpha: 0.35)),
            SizedBox(width: 6),
            Text('El cliente ofrece \$${_currentRequestPrecio.toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.person, size: 14, color: Colors.white.withValues(alpha: 0.35)),
            SizedBox(width: 6),
            Text(
              '${_clienteNombre ?? "Cliente"} · ',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${(_clienteReputation ?? 5.0) >= 4.5 ? "🟢" : (_clienteReputation ?? 5.0) >= 3.0 ? "🟡" : "🔴"} ${(_clienteReputation ?? 5.0).toStringAsFixed(1)}',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (_totalReportes > 0) ...[
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
              SizedBox(width: 6),
              Text(
                '⚠️ $_totalReportes reporte(s) de no pago',
                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
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
                  onPressed: _showOfferSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1A8CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: Color(0xFF1A8CFF).withValues(alpha: 0.4),
                  ),
                  child: Text('Ofertar',
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
