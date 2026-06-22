import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_client.dart';
import '../../services/map_config.dart';
import '../../services/proximity_service.dart';
import '../../services/socket_service_client.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/cache_service.dart';

import '../../services/logger_service.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'ofertas_recibidas_screen.dart';
import 'cancel_trip_screen.dart';
import '../../widgets/driver_nearby_warning_sheet.dart';
import '../shared/dispute_screen.dart';

class RastreoScreen extends StatefulWidget {
  const RastreoScreen({super.key});

  @override
  State<RastreoScreen> createState() => _RastreoScreenState();
}

class _RastreoScreenState extends State<RastreoScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  Map<String, dynamic>? _trip;
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  bool _mapError = false;
  Timer? _refreshTimer;
  final ProximityService _proximityService = ProximityService();
  StreamSubscription<Map<String, dynamic>>? _offerSub;
  StreamSubscription<Map<String, dynamic>>? _tripStatusSub;
  StreamSubscription<Map<String, dynamic>>? _tripCompletedSub;
  StreamSubscription<Map<String, dynamic>>? _tripCancelledSub;
  StreamSubscription<Map<String, dynamic>>? _finalizeRequestSub;
  StreamSubscription<Map<String, dynamic>>? _driverLocSub;
  double? _driverLat;
  double? _driverLng;
  double? _driverDisplayLat;
  double? _driverDisplayLng;
  double? _driverSpeed;
  double? _driverHeading;
  List<LatLng> _driverTrail = [];
  double? _clientLat;
  double? _clientLng;
  double _clientAccuracy = 0;
  final MapController _mapController = MapController();
  Timer? _autoFitTimer;
  Timer? _tripPollTimer;
  Timer? _offerPollTimer;
  StreamSubscription<bool>? _lifecycleSub;
  StreamSubscription<Position>? _clientPositionSub;
  Timer? _clientRetryTimer;
  int _clientGpsErrors = 0;
  bool _isCancelling = false;
  bool _driverNearby = false;
  late AnimationController _driverAnimCtrl;
  late final AnimationController _pulseController;
  late final List<Animation<double>> _pulseAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLifecycleService.instance.init();
    _driverAnimCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _driverAnimCtrl.addListener(_onDriverAnimTick);

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Interval(i * 0.3, 1.0, curve: Curves.easeOutCubic),
        ),
      );
    });
    _pulseController.repeat();

    final cachedTrip = CacheService.instance.getCachedActiveTrip();
    if (cachedTrip != null) {
      _trip = cachedTrip;
      _loading = false;
    }

    final cachedPos = CacheService.instance.getCachedDriverPosition();
    if (cachedPos != null) {
      _driverLat = (cachedPos['lat'] as num).toDouble();
      _driverLng = (cachedPos['lng'] as num).toDouble();
      _driverDisplayLat = _driverLat;
      _driverDisplayLng = _driverLng;
    }

    _initClientLocation();
    _startClientPositionStream();
    _load();

    _lifecycleSub = AppLifecycleService.instance.onBackgroundChanged.listen((isBackground) {
      if (!isBackground && mounted) {
        LoggerService.instance.info('Rastreo: app resumed, refreshing trip');
        _refreshAfterBackground();
        if (_clientPositionSub == null) {
          _startClientPositionStream();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driverAnimCtrl.dispose();
    _pulseController.dispose();
    _lifecycleSub?.cancel();
    _clientPositionSub?.cancel();
    _clientRetryTimer?.cancel();
    _offerSub?.cancel();
    _tripStatusSub?.cancel();
    _tripCompletedSub?.cancel();
    _tripCancelledSub?.cancel();
    _finalizeRequestSub?.cancel();
    _driverLocSub?.cancel();
    _autoFitTimer?.cancel();
    _tripPollTimer?.cancel();
    _offerPollTimer?.cancel();
    _refreshTimer?.cancel();
    _proximityService.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _trip != null) {
      LoggerService.instance.info('Rastreo: caching trip state on background');
      CacheService.instance.cacheActiveTrip(_trip!);
    }
  }

  Future<void> _refreshAfterBackground() async {
    try {
      final fresh = await ApiClient.instance.getActiveTrip();
      if (fresh != null && mounted) {
        setState(() {
          _trip = fresh;
          _loading = false;
        });
        CacheService.instance.cacheActiveTrip(fresh);
        _proximityService.startMonitoring(fresh, _showProximityAlert);
        if (_clientPositionSub == null) {
          _startClientPositionStream();
        }
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      LoggerService.instance.error('Rastreo: error refreshing after background', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initClientLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        ),
      );
      if (mounted) setState(() {
        _clientLat = pos.latitude;
        _clientLng = pos.longitude;
        _clientAccuracy = pos.accuracy;
      });
    } catch (e) {
      LoggerService.instance.warning('Rastreo: initial GPS failed, will use stream', e);
    }
  }

  void _startClientPositionStream() {
    _clientPositionSub?.cancel();
    _clientRetryTimer?.cancel();
    _clientGpsErrors = 0;

    try {
      final settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        timeLimit: const Duration(seconds: 30),
      );

      _clientPositionSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (Position pos) {
          if (!mounted) return;
          _clientGpsErrors = 0;
          setState(() {
            _clientLat = pos.latitude;
            _clientLng = pos.longitude;
            _clientAccuracy = pos.accuracy;
          });
          _fitMapBounds();
        },
        onError: (e) {
          LoggerService.instance.error('Rastreo: GPS stream error', e);
          _clientGpsErrors++;
          if (_clientGpsErrors > 5 && mounted) {
            _clientPositionSub?.cancel();
            _clientRetryTimer = Timer(const Duration(seconds: 15), () {
              if (mounted) _startClientPositionStream();
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      LoggerService.instance.error('Rastreo: GPS stream init error', e);
      _clientRetryTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) _startClientPositionStream();
      });
    }
  }

  Future<void> _load() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted) setState(() { _trip = trip; _loading = false; _mapError = false; });
      if (trip != null) {
        CacheService.instance.cacheActiveTrip(trip);
        _setupSocketListeners(trip['id']);
        _proximityService.startMonitoring(trip, _showProximityAlert);
        if (trip['estado'] == 'buscando_conductor') {
          _fetchOffers(trip['id']);
        }
        if (trip['estado'] == 'completado' && mounted) {
          _showFinalizeConfirmation({
            'tripId': trip['id'],
            'foto': trip['fotoEntrega'],
          });
        }
      } else {
        CacheService.instance.clearActiveTrip();
        if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setupSocketListeners(dynamic tripId) {
    _offerSub = SocketServiceClient.instance.onNewOffer.listen((data) {
      try {
        final eventTripId = data['tripId'] ?? data['trip_id'] ?? data['id'];
        if (eventTripId?.toString() == tripId.toString()) {
          _fetchOffers(tripId);
        }
      } catch (e) {
        LoggerService.instance.error('Rastreo: onNewOffer error', e);
      }
    });

    _tripStatusSub = SocketServiceClient.instance.onTripStatus.listen((data) {
      try {
        if (data['tripId']?.toString() == tripId.toString()) {
          _handleTripUpdate(data);
        }
      } catch (e) {
        LoggerService.instance.error('Rastreo: onTripStatus error', e);
      }
    });

    _tripCompletedSub = SocketServiceClient.instance.onTripCompleted.listen((data) {
      if (data['tripId']?.toString() != tripId.toString()) return;
      _proximityService.stopMonitoring();
      CacheService.instance.clearActiveTrip();
      CacheService.instance.clearDriverPosition();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    });

    _tripCancelledSub = SocketServiceClient.instance.onTripCancelled.listen((data) {
      if (data['tripId']?.toString() != tripId.toString()) return;
      _proximityService.stopMonitoring();
      CacheService.instance.clearActiveTrip();
      CacheService.instance.clearDriverPosition();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    });

    _finalizeRequestSub = SocketServiceClient.instance.onFinalizeRequest.listen((data) {
      try {
        if (data['tripId']?.toString() == tripId.toString()) {
          _showFinalizeConfirmation(data);
        }
      } catch (e) {
        LoggerService.instance.error('Rastreo: onFinalizeRequest error', e);
      }
    });

    _driverLocSub = SocketServiceClient.instance.onDriverLocation.listen((data) {
      try {
        final lat = double.tryParse(data['latitude']?.toString() ?? data['lat']?.toString() ?? '');
        final lng = double.tryParse(data['longitude']?.toString() ?? data['lng']?.toString() ?? '');
        if (lat != null && lng != null && mounted) {
          CacheService.instance.cacheDriverPosition(lat, lng);
          setState(() {
            _driverLat = lat;
            _driverLng = lng;
            _driverSpeed = double.tryParse(data['speed']?.toString() ?? '');
            _driverHeading = double.tryParse(data['heading']?.toString() ?? '');
            _driverTrail.add(LatLng(lat, lng));
            if (_driverTrail.length > 50) _driverTrail.removeAt(0);
            _checkDriverProximity();
          });
          _animateDriverTo(lat, lng);
          _fitMapBounds();
        }
      } catch (e) {
        LoggerService.instance.error('Rastreo: Error procesando ubicacion del conductor', e);
      }
    });

    _autoFitTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fitMapBounds();
    });

    _tripPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      if (!SocketServiceClient.instance.isConnected) {
        LoggerService.instance.info('Rastreo: socket disconnected, polling trip status');
        _refreshAfterBackground();
      }
    });

    _offerPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (_trip?['estado'] == 'buscando_conductor') {
        LoggerService.instance.info('Rastreo: polling offers');
        _fetchOffers(tripId);
      }
    });
  }

  void _handleTripUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    final newEstado = data['estado'] as String?;
    if (newEstado != null && _trip != null) {
      setState(() {
        _trip = {..._trip!, 'estado': newEstado, ...data};
      });
    }
  }

  Future<void> _fetchOffers(dynamic tripId) async {
    try {
      final offers = await ApiClient.instance.getOffers(tripId);
      if (mounted) setState(() => _offers = offers);
    } catch (_) {}
  }

  Future<void> _aceptarOferta(dynamic offerId) async {
    try {
      await ApiClient.instance.acceptOffer(_trip!['id'], offerId);
      final updated = await ApiClient.instance.getActiveTrip();
      if (mounted) {
        setState(() {
          if (updated != null) _trip = updated;
          _offers = [];
        });
      }
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  Future<void> _rechazarOferta(dynamic offerId) async {
    try {
      await ApiClient.instance.rejectOffer(_trip!['id'], offerId);
      if (mounted) {
        setState(() => _offers.removeWhere((o) => o['id'] == offerId));
      }
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  Future<void> _cancelar() async {
    if (_isCancelling) return;
    _isCancelling = true;

    final enCurso = _trip?['estado'] == 'en_curso';

    try {
      final result = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(builder: (_) => CancelTripScreen(enCurso: enCurso)),
      );

      if (result == null || result['reason'] == null) {
        _isCancelling = false;
        return;
      }

      final motivo = result['comment']!.isNotEmpty
          ? '${result['reason']}: ${result['comment']}'
          : result['reason']!;
      final tripId = _trip!['id'];
      final estado = _trip!['estado'] as String;

      if (enCurso) {
        await ApiClient.instance.requestCancellation(tripId, motivo: motivo);
        SocketServiceClient.instance.emit('trip:cancellation_requested', {
          'tripId': tripId,
          'motivo': motivo,
          'solicitadoPor': 'cliente',
        });
      } else {
        await ApiClient.instance.cancelTrip(tripId, motivo: motivo);
        SocketServiceClient.instance.emit('trip:cancelled', {
          'tripId': tripId,
          'motivo': motivo,
          'canceladoPor': 'cliente',
          'estadoAlCancelar': estado,
        });
      }

      if (mounted) {
        _pulseController.stop();
        _proximityService.stopMonitoring();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      _isCancelling = false;
    }
  }

  void _showProximityAlert(String message) {
    if (!mounted) return;
    _snack(message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aviso de proximidad'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  String? _pendingFinalizeData;

  void _showFinalizeConfirmation(Map<String, dynamic> data) {
    if (!mounted) return;
    _pendingFinalizeData = null;
    String? rejectionReason;
    final fotoUrl = data['foto'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final destino = _trip?['destino'] as Map<String, dynamic>?;
          final dir = destino?['direccion'] as String? ?? 'Destino';

          return AlertDialog(
            title: const Text('Confirmar entrega'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Entrega en:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(dir, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: NetworkImage(fotoUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '\u00bfConfirma que recibi\u00f3 correctamente la carga?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                          ...[
                    const Text('Motivo de rechazo (si aplica):', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    ...['Producto da\u00f1ado', 'Producto incorrecto', 'Conductor no se present\u00f3', 'Otro'].map(
                      (m) => RadioListTile<String>(
                        title: Text(m, style: const TextStyle(fontSize: 13)),
                        value: m,
                        groupValue: rejectionReason,
                        onChanged: (v) => setDialogState(() => rejectionReason = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final motivo = rejectionReason ?? 'Sin motivo especificado';
                  SocketServiceClient.instance.emit('trip:finalize_response', {
                    'tripId': data['tripId'],
                    'accepted': false,
                    'motivo': motivo,
                  });
                  Navigator.pop(ctx);
                  _snack('Rechazo registrado. Se notificar\u00e1 al administrador.');
                },
                child: const Text('No, rechazar', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () {
                  SocketServiceClient.instance.emit('trip:finalize_response', {
                    'tripId': data['tripId'],
                    'accepted': true,
                  });
                  Navigator.pop(ctx);
                  _snack('Entrega confirmada. \u00a1Gracias!');
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
                child: const Text('S\u00ed, confirmar entrega'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _fitMapBounds() {
    final origen = _trip?['origen'] as Map<String, dynamic>?;
    final destino = _trip?['destino'] as Map<String, dynamic>?;
    final points = <LatLng>[];
    if (_clientLat != null && _clientLng != null) {
      points.add(LatLng(_clientLat!, _clientLng!));
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
    if (_driverLat != null && _driverLng != null) {
      points.add(LatLng(_driverLat!, _driverLng!));
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

  Widget _buildMap(Map<String, dynamic> origen, Map<String, dynamic> destino) {
    final oLat = double.tryParse(origen['lat']?.toString() ?? '') ?? 0;
    final oLng = double.tryParse(origen['lng']?.toString() ?? '') ?? 0;
    final dLat = double.tryParse(destino['lat']?.toString() ?? '') ?? 0;
    final dLng = double.tryParse(destino['lng']?.toString() ?? '') ?? 0;

    if (_mapError) {
      return _buildMapError();
    }

    final markers = <Marker>[
      Marker(point: LatLng(oLat, oLng), width: 42, height: 42, child: Container(
        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        child: const Icon(Icons.person, color: Colors.white, size: 22),
      )),
      Marker(point: LatLng(dLat, dLng), width: 36, height: 36, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
    ];

    if (_clientLat != null && _clientLng != null) {
      final showAccurate = _clientAccuracy > 0 && _clientAccuracy < 100;
      markers.add(Marker(
        point: LatLng(_clientLat!, _clientLng!),
        width: showAccurate ? 36 : 44,
        height: showAccurate ? 36 : 44,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A3C6E),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: _clientAccuracy > 50 ? 3.0 : 2.5),
          ),
          child: Icon(
            _clientAccuracy > 100 ? Icons.gps_off : Icons.person_pin,
            color: Colors.white, size: showAccurate ? 20 : 24,
          ),
        ),
      ));
    }

    if (_driverDisplayLat != null && _driverDisplayLng != null) {
      markers.add(Marker(
        point: LatLng(_driverDisplayLat!, _driverDisplayLng!),
        width: 48, height: 48,
        child: Transform.rotate(
          angle: (_driverHeading ?? 0) * pi / 180,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.4), blurRadius: 8)],
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 26),
          ),
        ),
      ));
    }

    return Container(
      height: 280,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E0E0))),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng((oLat + dLat) / 2, (oLng + dLng) / 2),
              initialZoom: 12,
              onMapReady: () => _fitMapBounds(),
            ),
            children: [
              TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app', errorImage: const AssetImage('')),
              PolylineLayer(
                polylines: [
                  if (_driverTrail.length > 1)
                    Polyline(
                      points: List.from(_driverTrail),
                      color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                      strokeWidth: 4,
                    ),
                  Polyline(
                    points: _driverLat != null && _driverLng != null
                        ? [LatLng(_driverLat!, _driverLng!), LatLng(dLat, dLng)]
                        : [LatLng(oLat, oLng), LatLng(dLat, dLng)],
                    color: const Color(0xFF1565C0).withValues(alpha: 0.5),
                    strokeWidth: 3,
                  ),
                ],
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          if (_driverLat != null && _driverLng != null && _trip?['conductor'] != null)
            Positioned(
              left: 8, top: 8,
              child: _buildDriverDistanceCard(oLat, oLng),
            ),
          if (_clientLat != null && _clientLng != null)
            Positioned(
              right: 8, bottom: 8,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _centerOnClient,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.my_location, size: 20, color: Color(0xFF1A3C6E)),
                  ),
                ),
              ),
            ),
          if (_mapError)
            Positioned(
              right: 8, top: 8,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => setState(() => _mapError = false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.refresh, size: 18, color: Color(0xFF1A3C6E)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDriverAnimTick() {
    if (!mounted) return;
    final fromLat = _driverLat ?? _driverDisplayLat;
    final fromLng = _driverLng ?? _driverDisplayLng;
    if (fromLat == null || fromLng == null || _driverLat == null || _driverLng == null) return;
    final t = _driverAnimCtrl.value;
    _driverDisplayLat = fromLat + (_driverLat! - fromLat) * t;
    _driverDisplayLng = fromLng + (_driverLng! - fromLng) * t;
    setState(() {});
  }

  void _animateDriverTo(double lat, double lng) {
    if (_driverDisplayLat == null && _driverDisplayLng == null) {
      _driverDisplayLat = lat;
      _driverDisplayLng = lng;
      return;
    }
    _driverAnimCtrl
      ..reset()
      ..forward();
  }

  void _centerOnClient() {
    if (_clientLat == null || _clientLng == null) return;
    _mapController.move(LatLng(_clientLat!, _clientLng!), 15);
  }

  Widget _buildDriverDistanceCard(double oLat, double oLng) {
    final estado = _trip?['estado'] as String?;
    final destino = _trip?['destino'] as Map<String, dynamic>?;
    final dLat = double.tryParse(destino?['lat']?.toString() ?? '');
    final dLng = double.tryParse(destino?['lng']?.toString() ?? '');
    final spdKmph = (_driverSpeed ?? 0) * 3.6;
    final velocidadKmph = spdKmph > 5 ? spdKmph : 30;

    double distKm;
    String label;
    if (estado == 'aceptado') {
      distKm = _haversine(_driverLat!, _driverLng!, oLat, oLng);
      label = 'al punto de recogida';
    } else {
      distKm = (dLat != null && dLng != null)
          ? _haversine(_driverLat!, _driverLng!, dLat, dLng)
          : _haversine(_driverLat!, _driverLng!, oLat, oLng);
      label = 'al destino';
    }
    final min = distKm > 0 ? (distKm / velocidadKmph * 60).round() : 0;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping, size: 14, color: const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${distKm.toStringAsFixed(1)} km $label', style: const TextStyle(fontSize: 10, color: Color(0xFF757575))),
            Text('~$min min', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
            if (spdKmph > 5)
              Text('${spdKmph.toStringAsFixed(0)} km/h', style: const TextStyle(fontSize: 9, color: Color(0xFF1565C0))),
          ]),
        ]),
      ),
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180.0;

  Widget _buildMapError() {
    return Container(
      height: 200,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E0E0)), color: const Color(0xFFF5F5F5)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text('No se pudo cargar el mapa', style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 4),
            Text('Verifica tu conexi\u00f3n a internet', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => setState(() => _mapError = false),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C6E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _estadoLabel(String? estado) {
    switch (estado) {
      case 'buscando_conductor': return 'Buscando conductor';
      case 'aceptado':
        if (_driverLat != null) {
          final origen = _trip?['origen'] as Map<String, dynamic>?;
          if (origen != null) {
            final oLat = double.tryParse(origen['lat']?.toString() ?? '');
            final oLng = double.tryParse(origen['lng']?.toString() ?? '');
            if (oLat != null && oLng != null) {
              final dist = _haversine(_driverLat!, _driverLng!, oLat, oLng) * 1000;
              if (dist <= 1000) return 'Conductor cerca del punto de recogida';
            }
          }
          return 'Conductor en camino';
        }
        return 'Conductor asignado';
      case 'en_curso': {
        if (_driverLat != null) {
          final destino = _trip?['destino'] as Map<String, dynamic>?;
          if (destino != null) {
            final dLat = double.tryParse(destino['lat']?.toString() ?? '');
            final dLng = double.tryParse(destino['lng']?.toString() ?? '');
            if (dLat != null && dLng != null) {
              final dist = _haversine(_driverLat!, _driverLng!, dLat, dLng) * 1000;
              if (dist <= 500) return 'Llegando al destino';
            }
          }
        }
        return 'En camino a destino';
      }
      case 'completado': return 'Entrega completada';
      case 'finalizado': return 'Viaje finalizado';
      case 'cancelado': return 'Cancelado';
      default: return estado ?? '';
    }
  }

  bool get _isTripActive {
    final e = _trip?['estado'] as String?;
    return e == 'buscando_conductor' || e == 'aceptado' || e == 'en_curso';
  }

@override
  Widget build(BuildContext context) {
    final estado = _trip?['estado'] as String?;
    final isSearching = estado == 'buscando_conductor';

    return PopScope(
      canPop: !_isTripActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          _snack('Acci\u00f3n no permitida hasta finalizar el viaje.');
        }
      },
      child: Scaffold(
        backgroundColor: isSearching ? const Color(0xFFF5F7FA) : Colors.white,
        appBar: isSearching
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
                  onPressed: () {
                    if (_isTripActive) {
                      _snack('Acci\u00f3n no permitida hasta finalizar el viaje.');
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                title: const Text('Rastrear viaje', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _trip == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No tienes un viaje activo', style: TextStyle(fontSize: 15, color: Colors.black45)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Volver al inicio'),
                        ),
                      ],
                    ),
                  )
                : isSearching
                    ? _buildSearchContent()
                    : _buildTrackingLayout(),
      ),
    );
  }

  Widget _buildSearchContent() {
    final estado = _trip!['estado'] as String?;
    final origen = _trip!['origen'] as Map<String, dynamic>?;
    final destino = _trip!['destino'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRadarSearch(),
          const SizedBox(height: 16),
          _buildRouteCard(origen, destino),
          const SizedBox(height: 16),
          _buildOffersSection(),
          Center(
            child: TextButton.icon(
              onPressed: _cancelar,
              icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
              label: const Text('Cancelar viaje', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarSearch() {
    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                return SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ..._pulseAnimations.map((anim) {
                        final scale = anim.value;
                        final opacity = (1 - scale).clamp(0.0, 1.0);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2563EB)
                                  .withOpacity(opacity * 0.18),
                            ),
                          ),
                        );
                      }),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2563EB),
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Buscando conductores\ncercanos...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.3,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Esto puede tomar unos segundos.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200, height: 44,
          child: ElevatedButton.icon(
            onPressed: _cancelar,
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancelar viaje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(Map<String, dynamic>? origen, Map<String, dynamic>? destino) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ruta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(
            children: [
              Column(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle)),
                Container(width: 1.5, height: 20, color: Colors.grey.shade300),
                Container(width: 8, height: 8, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4CAF50), width: 2), shape: BoxShape.circle)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(origen?['direccion'] as String? ?? 'Sin direcci\u00f3n', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    Text(destino?['direccion'] as String? ?? 'Sin direcci\u00f3n', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    if (_offers.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('Esperando ofertas de conductores...', style: TextStyle(color: Colors.black45)),
      ));
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfertasRecibidasScreen(
              ofertas: _offers,
              trip: _trip!,
              onAccept: (offerId) => _aceptarOferta(offerId),
              onReject: (offerId) => _rechazarOferta(offerId),
            ),
          ),
        ).then((_) => _fetchOffers(_trip!['id'])),
        icon: const Icon(Icons.list_alt_rounded, size: 20),
        label: Text('Ver ofertas (${_offers.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }



  Widget _buildTrackingLayout() {
    final estado = _trip!['estado'] as String?;
    final conductor = _trip!['conductor'] as Map<String, dynamic>?;
    final origen = _trip!['origen'] as Map<String, dynamic>?;
    final destino = _trip!['destino'] as Map<String, dynamic>?;

    double distKm = 0;
    int min = 0;
    String distLabel = '';
    if (_driverLat != null && _driverLng != null) {
      final oLat = double.tryParse(origen?['lat']?.toString() ?? '');
      final oLng = double.tryParse(origen?['lng']?.toString() ?? '');
      final dLat = double.tryParse(destino?['lat']?.toString() ?? '');
      final dLng = double.tryParse(destino?['lng']?.toString() ?? '');
      if (estado == 'aceptado' && oLat != null && oLng != null) {
        distKm = _haversine(_driverLat!, _driverLng!, oLat, oLng);
        distLabel = 'al punto de recogida';
      } else if (dLat != null && dLng != null) {
        distKm = _haversine(_driverLat!, _driverLng!, dLat, dLng);
        distLabel = 'al destino';
      }
      final velocidadKmph = (_driverSpeed ?? 0) > 5 ? (_driverSpeed! * 3.6) : 30;
      min = distKm > 0 ? (distKm / velocidadKmph * 60).round() : 0;
    }

    final statusLabel = _estadoLabel(estado);

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              if (origen != null && destino != null) _buildMap(origen, destino),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _circleButton(Icons.arrow_back_ios_new_rounded, () {
                        if (_isTripActive) {
                          _snack('Acci\u00f3n no permitida hasta finalizar el viaje.');
                        } else {
                          Navigator.pop(context);
                        }
                      }),
                      const SizedBox(width: 12),
                      Text(statusLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD0E8FF),
                      border: Border.all(color: const Color(0xFF2D9CDB), width: 2),
                    ),
                    child: ClipOval(
                      child: Icon(Icons.person, size: 34, color: const Color(0xFF2D9CDB)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(conductor?['nombre'] as String? ?? 'Conductor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                            const SizedBox(width: 3),
                            Text(
                              (conductor?['rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _iconButton(Icons.phone_outlined, _callDriver),
                  const SizedBox(width: 10),
                  _iconButton(Icons.chat_bubble_outline_rounded, _openChat),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tiempo estimado de llegada', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        Text('~$min min', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: const Color(0xFFF0F0F0)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Distancia $distLabel', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          Text('${distKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _bottomAction(Icons.chat_bubble_outline_rounded, 'Chat', _openChat)),
                  Expanded(child: _bottomAction(Icons.phone_outlined, 'Llamar', _callDriver)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: _cancelar,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar viaje', style: TextStyle(color: Color(0xFFE53935), fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeScreen(trip: _trip!, role: 'cliente'))),
                  icon: const Icon(Icons.gavel_outlined, size: 18),
                  label: const Text('Reportar problema', style: TextStyle(fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1A1A2E)),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: const Color(0xFFF5F7FA), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: const Color(0xFF1A1A2E)),
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1A1A2E)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }

  void _callDriver() {
    final conductor = _trip?['conductor'] as Map<String, dynamic>?;
    final telefono = conductor?['telefono'] as String?;
    if (telefono != null && telefono.isNotEmpty) {
      launchUrl(Uri.parse('tel:$telefono'));
    } else {
      _snack('No hay n\u00famero de tel\u00e9fono disponible');
    }
  }

  void _openChat() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(trip: _trip!)));
  }
}


