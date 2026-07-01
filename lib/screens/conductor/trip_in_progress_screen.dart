import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker_plus/flutter_map_location_marker_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../../contracts/trip_status.dart';
import '../../services/api_client.dart';
import '../../services/map_config.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service_client.dart';
import '../../services/logger_service.dart';
import '../../services/network_monitor_service.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/cache_service.dart';
import '../../services/background_location_service.dart';
import '../../services/fraud_detection_service.dart';
import '../../services/api/trip_service.dart';
import '../../services/driver_location_service.dart';
import '../../services/route_service.dart';
import 'trip_chat_screen.dart';
import 'viaje_en_camino_screen.dart';
import 'viaje_llegada_destino_screen.dart';
import 'entrega_confirmada_screen.dart';
import 'resumen_viaje_screen.dart';
import 'calificar_cliente_screen.dart';
import 'sos_alert_screen.dart';
import '../shared/dispute_screen.dart';
import 'disputa_iniciada_wrapper.dart';

class TripInProgressScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;
  const TripInProgressScreen({super.key, this.trip});

  @override
  State<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends State<TripInProgressScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  bool _actionLoading = false;
  Timer? _locationTimer;
  StreamSubscription<Map<String, dynamic>>? _gpsSubscription;
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _posRetryTimer;
  int _posErrors = 0;
  double? _currentLat;
  double? _currentLng;
  double? _currentSpeed;
  int _elapsedSeconds = 0;
  String? _deliveryPhotoUrl;
  Timer? _elapsedTimer;
  StreamSubscription<Map<String, dynamic>>? _finalizeResponseSub;
  StreamSubscription<bool>? _lifecycleSub;
  final MapController _mapController = MapController();
  Timer? _tripStateTimer;
  bool _isCancelling = false;
  bool _isFinalizing = false;
  List<LatLng> _routePoints = [];
  bool _isRouteLoading = true;
  bool _locationWarningShown = false;
  int _locationFailCount = 0;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;
  static const Color _activeStep = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLifecycleService.instance.init();

    _gpsSubscription = NotificationService.instance.onNotification.listen(_onSocketEvent);
    _finalizeResponseSub = SocketServiceClient.instance.onFinalizeResponse.listen(_onFinalizeResponse);

    final cachedTrip = CacheService.instance.getCachedActiveTrip();
    if (cachedTrip != null) {
      _trip = cachedTrip;
      _loading = false;
    }

    _initLocation();
    if (widget.trip != null) {
      _trip = widget.trip;
      _loading = false;
      _startGpsTimer();
      _cacheTripState();
    } else if (_trip != null) {
      _loading = false;
      _startGpsTimer();
    } else {
      _fetchActiveTrip();
    }

    _loadRoute();

    _lifecycleSub = AppLifecycleService.instance.onBackgroundChanged.listen((isBackground) {
      try {
        if (!isBackground && mounted) {
          LoggerService.instance.info('TripInProgress: app resumed, restoring state');
          _restoreAfterBackground();
        }
      } catch (e) {
        LoggerService.instance.error('TripInProgress: lifecycle error', e);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleSub?.cancel();
    _positionStreamSub?.cancel();
    _posRetryTimer?.cancel();
    _stopGpsTimer();
    _elapsedTimer?.cancel();
    _gpsSubscription?.cancel();
    _finalizeResponseSub?.cancel();
    _tripStateTimer?.cancel();
    _cancelCountdown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      LoggerService.instance.info('TripInProgress: app backgrounded, caching trip state');
      _cacheTripState();
      BackgroundLocationService.instance.updateNotification(
        estado: _trip?['estado'] as String?,
        destino: _getDestinoDireccion(),
      );
    }
  }

  String? _getDestinoDireccion() {
    final destino = _trip?['destino'] as Map<String, dynamic>?;
    return destino?['direccion'] as String?;
  }

  void _cacheTripState() {
    if (_trip != null) {
      CacheService.instance.cacheActiveTrip(_trip!);
    }
  }

  Future<void> _loadRoute() async {
    final t = _trip ?? widget.trip;
    if (t == null) return;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    if (origen == null || destino == null) return;
    final oLat = double.tryParse(origen['lat']?.toString() ?? '');
    final oLng = double.tryParse(origen['lng']?.toString() ?? '');
    final dLat = double.tryParse(destino['lat']?.toString() ?? '');
    final dLng = double.tryParse(destino['lng']?.toString() ?? '');
    if (oLat == null || oLng == null || dLat == null || dLng == null) return;
    final points = await RouteService.getRoute(LatLng(oLat, oLng), LatLng(dLat, dLng));
    if (mounted) setState(() {
      _routePoints = points;
      _isRouteLoading = false;
    });
  }

  Future<void> _restoreAfterBackground() async {
    try {
      final fresh = await ApiClient.instance.getActiveTrip();
      if (fresh != null && mounted) {
        setState(() {
          _trip = fresh;
          _elapsedSeconds = _calcularElapsed(fresh);
        });
        _cacheTripState();
        _restartTimersIfNeeded();
      }
    } catch (e) {
      LoggerService.instance.error('TripInProgress: error restoring after background', e);
    }
  }

  int _calcularElapsed(Map<String, dynamic> trip) {
    final inicio = trip['inicio'] as String?;
    if (inicio == null) return _elapsedSeconds;
    try {
      final inicioDt = DateTime.parse(inicio);
      return DateTime.now().difference(inicioDt).inSeconds;
    } catch (_) {
      return _elapsedSeconds;
    }
  }

  void _restartTimersIfNeeded() {
    if (_locationTimer == null || !_locationTimer!.isActive) {
      _startGpsTimer();
    }
  }

  Timer? _countdownTimer;

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _fitMapBounds() {
    final origen = _trip?['origen'] as Map<String, dynamic>?;
    final destino = _trip?['destino'] as Map<String, dynamic>?;
    final points = <LatLng>[];
    if (_currentLat != null && _currentLng != null) {
      points.add(LatLng(_currentLat!, _currentLng!));
    }
    if (origen != null) {
      final oLat = double.tryParse(origen['lat']?.toString() ?? '');
      final oLng = double.tryParse(origen['lng']?.toString() ?? '');
      if (oLat != null && oLng != null) points.add(LatLng(oLat, oLng));
    }
    if (destino != null) {
      final dLat = double.tryParse(destino['lat']?.toString() ?? '');
      final dLng = double.tryParse(destino['lng']?.toString() ?? '');
      if (dLat != null && dLng != null) points.add(LatLng(dLat, dLng));
    }
    if (points.length < 2) {
      if (points.length == 1) {
        _mapController.move(points.first, 14);
      }
      return;
    }
    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        ),
      );
      if (mounted) setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      });
    } catch (e) {
      LoggerService.instance.error('trip_in_progress._initLocation error', e);
    }
    _startPositionStream();
  }

  void _startPositionStream() {
    _positionStreamSub?.cancel();
    _posRetryTimer?.cancel();
    _posErrors = 0;

    try {
      final settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        timeLimit: const Duration(seconds: 30),
      );

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (Position pos) {
          try {
            if (!mounted) return;
            _posErrors = 0;
            CacheService.instance.cacheDriverPosition(pos.latitude, pos.longitude);
            setState(() {
              _currentLat = pos.latitude;
              _currentLng = pos.longitude;
              _currentSpeed = pos.speed;
            });
          } catch (e) {
            LoggerService.instance.error('trip_in_progress: GPS data handler error', e);
          }
        },
        onError: (e) {
          LoggerService.instance.error('trip_in_progress: GPS stream error', e);
          _posErrors++;
          if (_posErrors > 5 && mounted) {
            _positionStreamSub?.cancel();
            _posRetryTimer = Timer(const Duration(seconds: 15), () {
              if (mounted) _startPositionStream();
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      LoggerService.instance.error('trip_in_progress: GPS stream init error', e);
      _posRetryTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) _startPositionStream();
      });
    }
  }

  void _onSocketEvent(Map<String, dynamic> event) {
    try {
      final tipo = event['__event'] as String?;
      if (tipo == 'driver:stop_gps') {
        _stopGpsTimer();
      } else if (tipo == 'trip:cancelled') {
        if (mounted) {
          _snack('El viaje ha sido cancelado');
          _stopGpsTimer();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      LoggerService.instance.error('trip_in_progress: onSocketEvent error', e);
    }
  }

  void _onFinalizeResponse(Map<String, dynamic> data) {
    try {
      _cancelCountdown();
      final accepted = data['accepted'] == true;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          Navigator.pop(context);
          if (accepted) {
            _finalizeTrip();
          } else {
            final motivo = data['motivo'] as String? ?? 'Cliente rechaz\u00f3 confirmaci\u00f3n de entrega';
            _snack('El cliente rechaz\u00f3 la confirmaci\u00f3n. Se abrir\u00e1 una disputa.');
            try {
              final disputeResult = await ApiClient.instance.disputeTrip(
                _trip?['id'],
                motivo: 'Rechazo de entrega',
                descripcion: motivo,
              );
              final disputeId = disputeResult['id'] ?? disputeResult['disputeId'];
              if (mounted) {
                final trip = _trip;
                final origenText = (trip?['origen'] as Map<String, dynamic>?)?['direccion'] as String? ?? '';
                final destinoText = (trip?['destino'] as Map<String, dynamic>?)?['direccion'] as String? ?? '';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DisputaIniciadaWrapper(
                      tripId: trip?['id'],
                      disputeId: disputeId,
                      motivo: motivo,
                      origen: origenText,
                      destino: destinoText,
                    ),
                  ),
                );
              }
            } catch (e) {
              LoggerService.instance.error('trip_in_progress: disputeTrip error', e);
              if (mounted) _snack('Error al abrir disputa.');
            }
          }
        });
      }
    } catch (e) {
      LoggerService.instance.error('trip_in_progress: onFinalizeResponse error', e);
    }
  }

  Future<String?> _takeDeliveryPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final url = await TripService.deliveryPhoto(_trip!['id'], bytes, 'delivery_${DateTime.now().millisecondsSinceEpoch}.jpg');
      return url;
    } catch (e) {
      LoggerService.instance.error('Error taking delivery photo', e);
      return null;
    }
  }

  Future<void> _requestFinalization() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar entrega'),
        content: const Text('\u00bfDesea tomar una foto como evidencia de la entrega?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Sin foto'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tomar foto'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deliveryPhotoUrl = await _takeDeliveryPhoto();
      if (_deliveryPhotoUrl == null && mounted) {
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al tomar la foto'),
            content: const Text('No se pudo subir la foto de evidencia. ¿Quieres intentarlo de nuevo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar sin foto'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
        if (retry == true) {
          _deliveryPhotoUrl = await _takeDeliveryPhoto();
        }
      }
    }

    if (!mounted) return;

    SocketServiceClient.instance.emit('trip:finalize_request', {
      'tripId': _trip!['id'],
      'trip': _trip,
      if (_deliveryPhotoUrl != null) 'foto': _deliveryPhotoUrl,
    });

    int timeoutSec = 30;
    if (!mounted) { setState(() => _actionLoading = false); return; }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _cancelCountdown();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          timeoutSec--;
          if (timeoutSec <= 0) {
            timer.cancel();
            _countdownTimer = null;
            Navigator.pop(ctx);
            if (mounted) {
              _snack('El cliente no respondi\u00f3. Finalizando viaje.');
              _finalizeTrip();
            }
          } else {
            setState(() {});
          }
        });
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Esperando confirmaci\u00f3n'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Solicitando confirmaci\u00f3n al cliente...'),
                  const SizedBox(height: 16),
                  Text('Tiempo restante: $timeoutSec s',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700,
                      color: timeoutSec < 10 ? Colors.red : _primaryDark,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _cancelCountdown();
                    SocketServiceClient.instance.emit('trip:finalize_cancelled', {
                      'tripId': _trip?['id'],
                    });
                    Navigator.pop(ctx);
                    if (mounted) {
                      _snack('Finalizaci\u00f3n cancelada.');
                    }
                  },
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
    setState(() => _actionLoading = false);
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted) setState(() { _trip = trip; _loading = false; });
      if (trip != null) {
        _startGpsTimer();
      } else {
        LoggerService.instance.warning('trip_in_progress: no active trip found');
      }
    } catch (e) {
      LoggerService.instance.error('trip_in_progress._fetchActiveTrip error', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startGpsTimer() async {
    if (_locationTimer != null) return;

    final granted = await _requestLocationPermission();
    if (!granted) return;

    DriverLocationService.instance.pause(); // evitar triple GPS

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendLocation());
    _sendLocation();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    _tripStateTimer?.cancel();
    _tripStateTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted) return;
      if (!SocketServiceClient.instance.isConnected) {
        LoggerService.instance.info('TripInProgress: polling trip state via API');
        try {
          final fresh = await ApiClient.instance.getActiveTrip();
          if (fresh != null && mounted) {
            final oldEstado = _trip?['estado'] as String?;
            final newEstado = fresh['estado'] as String?;
            if (oldEstado != null && newEstado != null && oldEstado != newEstado) {
              LoggerService.instance.info('TripInProgress: estado changed $oldEstado -> $newEstado');
              setState(() { _trip = fresh; });
            }
          }
        } catch (_) {}
      }
    });
  }

  void _stopGpsTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _elapsedTimer?.cancel();
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isGranted) return true;
    status = await Permission.location.request();
    if (status.isGranted) return true;
    if (!mounted) return false;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permiso de ubicaci\u00f3n'),
        content: const Text('Esta funci\u00f3n requiere acceso a la ubicaci\u00f3n para enviar tu posici\u00f3n en tiempo real.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir ajustes')),
        ],
      ),
    );
    if (shouldOpen == true) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _sendLocation() async {
    if (_currentLat == null || _currentLng == null) {
      _locationFailCount++;
      if (_locationFailCount > 3 && !_locationWarningShown && mounted) {
        _locationWarningShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('\u26a0\ufe0f No se puede obtener tu ubicaci\u00f3n. Revisa los permisos de GPS.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    _locationFailCount = 0;
    _locationWarningShown = false;
    if (!NetworkMonitorService.instance.isOnline) return;

    // Socket para el cliente (tiempo real)
    if (_trip != null && SocketServiceClient.instance.isConnected) {
      SocketServiceClient.instance.emit('driver:location', {
        'tripId': _trip!['id'] ?? _trip!['_id'],
        'latitude': _currentLat,
        'longitude': _currentLng,
        'speed': _currentSpeed ?? 0,
      });
    }

    // HTTP para persistencia backend
    try {
      await ApiClient.instance.updateLocation(_currentLat!, _currentLng!);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('429') || msg.contains('RateLimited')) return;
      LoggerService.instance.error('_sendLocation error', e);
    }
  }

  Future<void> _startTrip() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);
    try {
      await ApiClient.instance.startTrip(_trip!['id']);
      _trip!['estado'] = TripStatus.enCurso;
      if (mounted) setState(() {});
      _snack('Viaje iniciado');
      _startGpsTimer();
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _finalizeTrip() async {
    if (_trip == null || _isFinalizing) return;
    _isFinalizing = true;
    setState(() => _actionLoading = true);
    try {
      final t = _trip!;
      final montoFinal = t['precioFinal'] as num? ?? t['precioEstimado'] as num?;
      await ApiClient.instance.finalizeTrip(t['id'], montoFinal: montoFinal);
      t['estado'] = TripStatus.finalizado;
      _stopGpsTimer();
      if (!mounted) return;

      final precio = t['precioFinal'] as num? ?? t['precioEstimado'] as num? ?? 0;
      final pctComision = t['porcentajeComision'] as num? ?? 10;
      final precioStr = '\$${precio.toStringAsFixed(0)}';
      final comisionVal = precio * (pctComision / 100);
      final comisionStr = '- \$${comisionVal.toStringAsFixed(0)}';
      final totalStr = '\$${(precio - comisionVal).toStringAsFixed(0)}';
      final cliente = t['cliente'] as Map<String, dynamic>?;
      final nombreCliente = cliente?['nombre'] as String? ?? '';
      final rating = cliente?['calificacion'] is num ? (cliente!['calificacion'] as num).toDouble() : 4.0;
      final origenText = (t['origen'] as Map<String, dynamic>?)?['direccion'] as String? ?? '';
      final destinoText = (t['destino'] as Map<String, dynamic>?)?['direccion'] as String? ?? '';

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EntregaConfirmadaScreen(
            nombreCliente: nombreCliente,
            ratingCliente: rating,
            precioAcordado: precioStr,
            comision: comisionStr,
            porcentajeComision: '${pctComision.toInt()}%',
            gananciaTotal: totalStr,
            onVerResumen: () => _pushResumenViaje(
              t, precioStr, comisionStr, '${pctComision.toInt()}%', totalStr, origenText, destinoText,
            ),
            onVolverInicio: () => _pushCalificarCliente(nombreCliente, rating),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
      _isFinalizing = false;
    }
  }

  void _pushResumenViaje(
    Map<String, dynamic> t,
    String precioStr, String comisionStr, String pctComision, String totalStr,
    String origenText, String destinoText,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumenViajeScreen(
          data: ResumenViajeData(
            origen: origenText,
            destino: destinoText,
            distanciaTotal: t['distancia'] != null
                ? '${t['distancia']} km'
                : '${_haversine(
              double.tryParse((t['origen'] as Map?)?['lat']?.toString() ?? '') ?? 0,
              double.tryParse((t['origen'] as Map?)?['lng']?.toString() ?? '') ?? 0,
              double.tryParse((t['destino'] as Map?)?['lat']?.toString() ?? '') ?? 0,
              double.tryParse((t['destino'] as Map?)?['lng']?.toString() ?? '') ?? 0,
            ).toStringAsFixed(1)} km (aprox.)',
            duracionTotal: _formatElapsed(),
            precioAcordado: precioStr,
            comision: comisionStr,
            porcentajeComision: pctComision,
            gananciaTotal: totalStr,
            pagoRecibido: 'Efectivo',
          ),
        ),
      ),
    );
  }

  void _pushCalificarCliente(String nombreCliente, double rating) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalificarClienteScreen(
          nombreCliente: nombreCliente,
          ratingActual: rating,
          onEnviar: (estrellas, comentario) async {
            try {
              await ApiClient.instance.rateTrip(_trip?['id'], estrellas, comentario: comentario);
            } catch (_) {}
            if (!context.mounted) return;
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
    );
  }

  String _formatElapsed() {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _isTripActive {
    final e = _trip?['estado'] as String?;
    return e == TripStatus.aceptado || e == TripStatus.enCamino || e == TripStatus.llegada || e == TripStatus.enCurso || e == TripStatus.entregado || e == TripStatus.esperaConfirmacion;
  }

  bool get _isNearDestination {
    if (_currentLat == null || _currentLng == null) return false;
    final destino = _trip?['destino'] as Map<String, dynamic>?;
    if (destino == null) return false;
    final dLat = double.tryParse(destino['lat']?.toString() ?? '');
    final dLng = double.tryParse(destino['lng']?.toString() ?? '');
    if (dLat == null || dLng == null) return false;
    final dist = _haversine(_currentLat!, _currentLng!, dLat, dLng) * 1000;
    return dist <= 150;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: _bgLight, body: const Center(child: CircularProgressIndicator()));
    }
    if (_trip == null) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(backgroundColor: _white, foregroundColor: _textDark, elevation: 0, title: const Text('Viaje en curso')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No hay viaje activo', style: TextStyle(fontSize: 16, color: Colors.black45)),
          ]),
        ),
      );
    }

    final t = _trip!;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';

    return PopScope(
      canPop: !_isTripActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          _snack('Acci\u00f3n no permitida hasta finalizar el viaje.');
        }
      },
      child: Scaffold(
        backgroundColor: _bgLight,
        body: Column(
          children: [
            _buildHeader(context, estado),
            Expanded(child: _buildMapWithContent(t, origen, destino, estado)),
            _buildBottomNav(t, estado),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String estado) {
    String label;
    switch (estado) {
      case TripStatus.aceptado: label = 'Aceptado'; break;
      case TripStatus.enCamino: label = 'En camino'; break;
      case TripStatus.llegada: label = 'Llegada al origen'; break;
      case TripStatus.enCurso: label = 'En curso'; break;
      case TripStatus.entregado: label = 'Entregado'; break;
      case TripStatus.esperaConfirmacion: label = 'Esperando confirmación'; break;
      case TripStatus.finalizado: label = 'Finalizado'; break;
      default: label = 'Viaje en curso';
    }
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isTripActive) {
                _snack('Acci\u00f3n no permitida hasta finalizar el viaje.');
              } else {
                Navigator.pop(context);
              }
            },
            child: Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
          ),
          const SizedBox(width: 12),
          const Text('Viaje en curso', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _accentGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _accentGreen.withValues(alpha: 0.4))),
            child: Text(label, style: TextStyle(color: _accentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEnCaminoPanel(Map<String, dynamic> t) {
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final origen = t['origen'] as Map<String, dynamic>?;
    final oLat = double.tryParse(origen?['lat']?.toString() ?? '') ?? 0;
    final oLng = double.tryParse(origen?['lng']?.toString() ?? '') ?? 0;
    final distOrigen = (_currentLat != null && _currentLng != null && oLat != 0)
        ? _haversine(_currentLat!, _currentLng!, oLat, oLng)
        : 0.0;
    final etaMin = distOrigen > 0 ? (distOrigen / 30 * 60).round() : 0;

    return ViajeEnCaminoScreen(
      nombreCliente: cliente?['nombre'] as String? ?? 'Cliente',
      ratingCliente: (cliente?['calificacion'] as num?)?.toDouble() ?? 5.0,
      tiempoEstimado: etaMin > 0 ? '~$etaMin min' : '--',
      distancia: distOrigen > 0 ? '${distOrigen.toStringAsFixed(1)} km' : '--',
      onChat: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TripChatScreen(trip: t))),
      onLlamar: () => _showClientPhone(t),
      onCancelarViaje: () => _cancelTrip(t),
    );
  }

  Widget _buildLlegadaOrigenPanel(Map<String, dynamic> t) {
    final cliente = t['cliente'] as Map<String, dynamic>?;
    return ViajeEnCaminoScreen(
      nombreCliente: cliente?['nombre'] as String? ?? 'Cliente',
      ratingCliente: (cliente?['calificacion'] as num?)?.toDouble() ?? 5.0,
      tiempoEstimado: '--',
      distancia: '0.0 km',
      onChat: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TripChatScreen(trip: t))),
      onLlamar: () => _showClientPhone(t),
      actionLabel: 'Iniciar viaje',
      actionIcon: Icons.play_arrow_rounded,
      onAction: _startTrip,
      bannerMessage: 'Has llegado al origen. Inicia el viaje cuando estés listo.',
    );
  }

  Widget _buildLlegadaDestinoPanel(Map<String, dynamic> t) {
    final cliente = t['cliente'] as Map<String, dynamic>?;
    return LlegadaDestinoScreen(
      nombreCliente: cliente?['nombre'] as String? ?? 'Cliente',
      ratingCliente: (cliente?['calificacion'] as num?)?.toDouble() ?? 5.0,
      isFinalizando: _actionLoading,
      onChat: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TripChatScreen(trip: t))),
      onLlamar: () => _showClientPhone(t),
      onHeLlegado: _requestFinalization,
      onSubirFoto: () async {
        final url = await _takeDeliveryPhoto();
        if (url != null && mounted) {
          setState(() => _deliveryPhotoUrl = url);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de evidencia subida correctamente')),
          );
        }
      },
    );
  }

  Widget _buildTripPanel(Map<String, dynamic> t, Map<String, dynamic>? origen, Map<String, dynamic>? destino, String estado) {
    final oLat = double.tryParse(origen?['lat']?.toString() ?? '') ?? 0;
    final oLng = double.tryParse(origen?['lng']?.toString() ?? '') ?? 0;
    final dLat = double.tryParse(destino?['lat']?.toString() ?? '') ?? 0;
    final dLng = double.tryParse(destino?['lng']?.toString() ?? '') ?? 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: _white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_currentLat != null)
            _buildTripInfoBar(oLat, oLng, dLat, dLng),
          const SizedBox(height: 12),
          _buildStepper(estado),
          const SizedBox(height: 12),
          _routeRow(Icons.trip_origin, 'Origen', origen?['direccion'] as String? ?? '', Colors.green),
          const SizedBox(height: 6),
          _routeRow(Icons.location_on, 'Destino', destino?['direccion'] as String? ?? '', Colors.red),
          if (estado == TripStatus.enCurso && _isNearDestination) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _accentGreen.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.check_circle, size: 18, color: _accentGreen),
                const SizedBox(width: 8),
                const Expanded(child: Text('Has llegado al destino', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              ]),
            ),
          ],
          if (estado == TripStatus.enCurso && _currentLat == null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _requestFinalization,
                icon: const Icon(Icons.location_off, size: 18),
                label: const Text('Finalizar sin GPS', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _infoChip('Carga', t['carga'] as String? ?? 'N/A'),
            _infoChip('Precio', '\$${(t['precioFinal'] as num? ?? t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}'),
          ]),
          const SizedBox(height: 12),
          _clientSection(t['cliente'] as Map<String, dynamic>?, t),
          const SizedBox(height: 12),
          if (estado == TripStatus.aceptado || estado == TripStatus.llegada)
            _actionButton('Iniciar viaje', _startTrip, _primaryDark)
          else if (estado == TripStatus.enCurso) ...[
            if (_isNearDestination)
              _actionButton('Finalizar viaje ✓', _requestFinalization, _accentGreen)
            else ...[
              _actionButton('Finalizar viaje', _requestFinalization, _primaryBlue),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Finaliza cuando estés en el punto de destino',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  )),
                ]),
              ),
            ],
          ]
          else if (estado == TripStatus.esperaConfirmacion)
            _actionButton('Confirmar finalización', _finalizeTrip, _primaryBlue),
        ]),
      ),
    );
  }

  Widget _buildMapWithContent(Map<String, dynamic> t, Map<String, dynamic>? origen, Map<String, dynamic>? destino, String estado) {
    final oLat = double.tryParse(origen?['lat']?.toString() ?? '') ?? 0;
    final oLng = double.tryParse(origen?['lng']?.toString() ?? '') ?? 0;
    final dLat = double.tryParse(destino?['lat']?.toString() ?? '') ?? 0;
    final dLng = double.tryParse(destino?['lng']?.toString() ?? '') ?? 0;
    final centerLat = _currentLat ?? oLat;
    final centerLng = _currentLng ?? oLng;

    final markers = <Marker>[
      Marker(point: LatLng(oLat, oLng), width: 40, height: 40, child: Container(
        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        child: const Icon(Icons.check, color: Colors.white, size: 20),
      )),
      Marker(point: LatLng(dLat, dLng), width: 40, height: 40, child: Container(
        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        child: const Icon(Icons.location_on, color: Colors.white, size: 20),
      )),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: 13,
            onMapReady: _fitMapBounds,
          ),
          children: [
            TileLayer(
              urlTemplate: MapConfig.tileUrl,
              userAgentPackageName: 'com.cargaexpress.app',
              maxZoom: 22,
            ),
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: Colors.black.withValues(alpha: 0.2),
                    strokeWidth: 8,
                  ),
                  Polyline(
                    points: _routePoints,
                    color: const Color(0xFF2563EB),
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
            CurrentLocationLayer(
              alignPositionOnUpdate: AlignOnUpdate.always,
              style: const LocationMarkerStyle(
                marker: DefaultLocationMarker(
                  color: Color(0xFF2563EB),
                  child: Icon(Icons.navigation, color: Colors.white, size: 20),
                ),
                markerSize: Size(40, 40),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: estado == TripStatus.aceptado || estado == TripStatus.enCamino
              ? _buildEnCaminoPanel(t)
              : (estado == TripStatus.llegada)
                  ? _buildLlegadaOrigenPanel(t)
                  : (estado == TripStatus.enCurso && _isNearDestination)
                      ? _buildLlegadaDestinoPanel(t)
                      : _buildTripPanel(t, origen, destino, estado),
        ),
      ],
    );
  }

  Widget _buildTripInfoBar(double oLat, double oLng, double dLat, double dLng) {
    final distOrigen = _haversine(_currentLat!, _currentLng!, oLat, oLng);
    final distDestino = _haversine(_currentLat!, _currentLng!, dLat, dLng);
    final spdKmph = (_currentSpeed ?? 0) * 3.6;
    final velocidad = spdKmph > 5 ? spdKmph : 30.0;
    final minDestino = distDestino > 0 ? (distDestino / velocidad * 60).round() : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('A ${distOrigen.toStringAsFixed(1)} km del origen', style: TextStyle(fontSize: 12, color: _textGrey)),
          const SizedBox(height: 4),
          Row(children: [
            Text('Destino: ', style: TextStyle(fontSize: 12, color: _textGrey)),
            Text('~$minDestino min', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _primaryDark)),
            if (spdKmph > 5) ...[
              const SizedBox(width: 6),
              Text('${spdKmph.toStringAsFixed(0)} km/h', style: TextStyle(fontSize: 11, color: _primaryBlue)),
            ],
          ]),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_outlined, size: 14, color: _primaryBlue),
            const SizedBox(width: 4),
            Text(_formatElapsed(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _primaryBlue)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStepper(String estado) {
    final steps = ['Aceptado', 'En camino', 'Llegada', 'En curso', 'Entregado', 'Esperando conf.', 'Finalizado'];
    final estados = [TripStatus.aceptado, TripStatus.enCamino, TripStatus.llegada, TripStatus.enCurso, TripStatus.entregado, TripStatus.esperaConfirmacion, TripStatus.finalizado];
    final current = estados.indexOf(estado);
    if (current < 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(height: 2, color: i ~/ 2 < current ? _activeStep : Colors.grey.shade300));
        }
        final idx = i ~/ 2;
        final active = idx <= current;
        return Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: active ? _activeStep : Colors.grey.shade300, shape: BoxShape.circle),
          child: Center(
            child: idx < current
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${idx + 1}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );
      }),
    );
  }

  Widget _routeRow(IconData icon, String label, String dir, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        Text(dir, style: const TextStyle(fontWeight: FontWeight.w500)),
      ])),
    ]);
  }

  Widget _infoChip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _textGrey)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _clientSection(Map<String, dynamic>? cliente, Map<String, dynamic> t) {
    if (cliente == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: _primaryDark, child: Text(_initials(cliente['nombre'] as String? ?? ''), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(child: Text(cliente['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
        if (cliente['telefono'] != null)
          IconButton(icon: const Icon(Icons.phone, size: 20), color: _primaryBlue, onPressed: () => _showClientPhone(t)),
      ]),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        onPressed: _actionLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
        ),
        child: _actionLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Widget _buildBottomNav(Map<String, dynamic> t, String estado) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      decoration: const BoxDecoration(color: _white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _navItem(Icons.chat_bubble_outline, 'Chat', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TripChatScreen(trip: t)));
        }),
        _navItem(Icons.phone_outlined, 'Llamar', () => _showClientPhone(t)),
        _navItem(Icons.info_outline, 'Detalle', () => _showClientDetail(t)),
        _navItem(Icons.gavel_outlined, 'Reportar', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeScreen(trip: t, role: 'conductor')));
        }),
        _navItem(Icons.emergency_outlined, 'SOS', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SOSAlertScreen()));
        }),
        if (estado == TripStatus.aceptado)
          _navItem(Icons.cancel_outlined, 'Cancelar', () => _cancelTrip(t)),
        if (estado == TripStatus.enCurso)
          _navItem(Icons.report_problem_outlined, 'Solicitar cancelaci\u00f3n', () => _requestCancellation(t)),
      ]),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: _textGrey),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: _textGrey)),
      ]),
    );
  }

  void _showClientPhone(Map<String, dynamic> t) {
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final nombre = cliente?['nombre'] as String? ?? 'Cliente';
    final telefono = cliente?['telefono'] as String?;
    if (telefono == null || telefono.isEmpty) {
      _snack('No hay n\u00famero de tel\u00e9fono disponible');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Contactar a $nombre'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.phone, size: 48, color: _primaryBlue),
          const SizedBox(height: 12),
          Text(telefono, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('$nombre - Cliente', style: const TextStyle(color: _textGrey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showClientDetail(Map<String, dynamic> t) {
    final cliente = t['cliente'] as Map<String, dynamic>?;
    if (cliente == null) {
      _snack('No hay informaci\u00f3n del cliente disponible');
      return;
    }
    final nombre = cliente['nombre'] as String? ?? 'Sin nombre';
    final telefono = cliente['telefono'] as String?;
    final calificacion = cliente['calificacion'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informaci\u00f3n del cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _primaryDark,
              child: Text(
                _initials(nombre),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ),
            const SizedBox(height: 12),
            Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: _textDark)),
            if (telefono != null && telefono.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.phone, size: 16, color: _primaryBlue),
                const SizedBox(width: 6),
                Text(telefono, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
            ],
            if (calificacion != null) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ...List.generate(5, (i) {
                  final val = calificacion is num ? calificacion.toInt() : 0;
                  return Icon(
                    i < val ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFF8F00),
                    size: 24,
                  );
                }),
                const SizedBox(width: 4),
                Text(calificacion.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _cancelTrip(Map<String, dynamic> t) async {
    final estado = t['estado'] as String?;
    if (estado == TripStatus.enCurso) {
      _snack('El viaje est\u00e1 en curso. Usa "Solicitar cancelaci\u00f3n" para pedir la cancelaci\u00f3n al administrador.');
      _requestCancellation(t);
      return;
    }
    final motivoCtrl = TextEditingController();
    String? motivoSeleccionado;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancelar viaje'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('El cliente ser\u00e1 notificado. Esta acci\u00f3n ser\u00e1 revisada.', style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Motivo de cancelaci\u00f3n:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              ...['Problema con el cliente', 'Veh\u00edculo no disponible', 'Emergencia', 'Otro'].map((m) => RadioListTile<String>(
                title: Text(m, style: const TextStyle(fontSize: 14)),
                value: m,
                groupValue: motivoSeleccionado,
                onChanged: (v) => setDialogState(() => motivoSeleccionado = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              if (motivoSeleccionado != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe el problema (opcional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            ElevatedButton(
              onPressed: motivoSeleccionado == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              child: const Text('Cancelar viaje'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || motivoSeleccionado == null) return;

    FraudDetectionService.instance.checkCancellation(ApiClient.instance.userId ?? '');

    try {
      final desc = motivoCtrl.text.trim();
      await ApiClient.instance.cancelTrip(t['id'], motivo: desc.isNotEmpty ? '$motivoSeleccionado: $desc' : motivoSeleccionado);
      if (mounted) {
        _snack('Viaje cancelado. Se ha notificado al cliente.');
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  Future<void> _requestCancellation(Map<String, dynamic> t) async {
    if (_isCancelling) return;
    _isCancelling = true;

    final motivoCtrl = TextEditingController();
    String? motivoSeleccionado;

    try {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Solicitar cancelaci\u00f3n'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('El viaje est\u00e1 en curso. Se notificar\u00e1 al cliente y a soporte.', style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500))),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Motivo de la solicitud:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                ...['Problema con el cliente', 'Emergencia', 'Veh\u00edculo averiado', 'Otro'].map((m) => RadioListTile<String>(
                  title: Text(m, style: const TextStyle(fontSize: 14)),
                  value: m,
                  groupValue: motivoSeleccionado,
                  onChanged: (v) => setDialogState(() => motivoSeleccionado = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
                if (motivoSeleccionado != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: motivoCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Explica con detalle lo que est\u00e1 pasando',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
              ElevatedButton(
                onPressed: motivoSeleccionado == null ? null : () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                child: const Text('Enviar solicitud'),
              ),
            ],
          ),
        ),
      );

      if (confirmado != true || motivoSeleccionado == null) return;

      final desc = motivoCtrl.text.trim();
      final motivo = desc.isNotEmpty ? '$motivoSeleccionado: $desc' : motivoSeleccionado;
      await ApiClient.instance.requestCancellation(t['id'], motivo: motivo);
      if (mounted) {
        _snack('Solicitud de cancelaci\u00f3n enviada. Se notificar\u00e1 al cliente y a soporte.');
      }
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      motivoCtrl.dispose();
      _isCancelling = false;
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180.0;

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}
