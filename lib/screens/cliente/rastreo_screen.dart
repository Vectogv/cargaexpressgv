import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/trip.dart';
import '../../contracts/cancelacion.dart';
import '../../contracts/trip_status.dart';
import '../../services/api/trip_service.dart';
import '../../services/api/offer_service.dart';
import '../../services/api/http_client.dart';
import '../../services/api_client.dart';
import '../../services/map_config.dart';
import '../../services/socket_service_client.dart';
import '../../services/sos_service.dart';
import '../../widgets/driver_nearby_warning_sheet.dart';
import '../shared/action_key.dart';
import 'busqueda_conductor_view.dart';
import 'cancel_trip_screen.dart';
import 'ofertas_recibidas_screen.dart';
import 'oferta_aceptada_screen.dart';
import 'confirmar_entrega_screen.dart';
import 'viaje_finalizado.dart';
import 'reportar_problema_screen.dart';
import 'conductor_en_la_zona_screen.dart';
import 'llegada_al_destino_screen.dart';
import 'chat_screen.dart';
import 'emergencia_chat_screen.dart';
import 'soporte_screen.dart';

class RastreoScreen extends StatefulWidget {
  const RastreoScreen({super.key});

  @override
  State<RastreoScreen> createState() => _RastreoScreenState();
}

class _RastreoScreenState extends State<RastreoScreen> {
  static const double _proximidadKm = 1.0;
  static const double _zonaKm = 0.05;
  Trip? _trip;
  final List<Map<String, dynamic>> _ofertas = [];
  String _status = TripStatus.buscando;
  bool _loading = false;
  bool _cancelling = false;
  bool _hasOffers = false;
  bool _offerAcceptedShown = false;
  bool _finalizeShown = false;
  bool _finalizedShown = false;
  // Una clave de idempotencia por acción del usuario (se reutiliza si reintenta).
  final ActionKey _confirmCloseKey = ActionKey();
  final ActionKey _rejectCloseKey = ActionKey();
  bool _isNavigating = false;
  bool _socketListenersSetUp = false;

  StreamSubscription? _positionSub;
  StreamSubscription<Map<String, dynamic>>? _tripStatusSub;
  StreamSubscription<Map<String, dynamic>>? _tripCancelledSub;
  StreamSubscription<Map<String, dynamic>>? _newOfferSub;
  StreamSubscription<Map<String, dynamic>>? _offerAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _tripAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _tripStartedSub;
  StreamSubscription<Map<String, dynamic>>? _driverLocationSub;
  StreamSubscription<Map<String, dynamic>>? _finalizeRequestSub;
  StreamSubscription<Map<String, dynamic>>? _finalizeCancelledSub;
  StreamSubscription<Map<String, dynamic>>? _tripFinalizedSub;
  StreamSubscription<bool>? _connectionSub;
  ModalRoute<dynamic>? _route;
  bool _sosSending = false;

  Timer? _pollingTimer;
  Timer? _fallbackPollingTimer;
  Timer? _proximityTimer;
  Timer? _cercanosTimer;
  List<Map<String, dynamic>> _cercanos = [];
  bool _proximityAlertShown = false;
  bool _conductorEnLaZonaShown = false;
  double _driverLat = 0;
  double _driverLng = 0;
  // Throttle de reconstrucciones por `driver:location` (máx. 1 por segundo).
  DateTime _lastDriverRebuild = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _driverRebuildTimer;
  Map<String, dynamic>? _pendingFinalizeRequest;
  final DateTime _pantallaAbierta = DateTime.now();
  // Mapa de búsqueda: tiles y opciones creados una vez, no en cada build().
  late final TileLayer _tileLayer = TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app');
  MapOptions? _nearbyMapOptions;
  LatLng? _nearbyMapCenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _route = ModalRoute.of(context);
      _load();
    });

    _connectionSub = SocketServiceClient.instance.onConnection.listen((connected) {
      if (!connected || !mounted || _trip == null) return;
      SocketServiceClient.instance.joinTrip(_trip!.id);
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (_trip == null) {
        final active = await TripService.getActiveTrip();
        if (active != null && mounted) {
          _trip = Trip.fromJson(active);
          final estado = _trip?.estado;
          if (estado != null) {
            setState(() => _status = estado);
          }
          SocketServiceClient.instance.joinTrip(_trip!.id);
        }
      }

      if (!_socketListenersSetUp) {
        _setupSocketListeners();
        _socketListenersSetUp = true;
      }

      if (_trip != null && _status != TripStatus.buscando) {
        await _startLocationUpdates();
      }

      if (_status == TripStatus.buscando && mounted) {
        _startPolling();
      }

      _startFallbackPolling();
    } catch (e) {
      debugPrint('Error en _load: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al cargar el viaje. Verifica tu conexión.'),
            action: SnackBarAction(label: 'Reintentar', onPressed: _load),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _safePop() {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.maybePop(context).then((_) {
      _isNavigating = false;
    }).catchError((_) {
      _isNavigating = false;
    });
  }

  void _safePush(Widget screen) {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      _isNavigating = false;
    }).catchError((_) {
      _isNavigating = false;
    });
  }

  void _safeReplace(Widget screen) {
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      _isNavigating = false;
    }).catchError((_) {
      _isNavigating = false;
    });
  }

  void _safePopUntilFirst() {
    if (_isNavigating) return;
    _isNavigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
      _isNavigating = false;
    });
  }

  void _setupSocketListeners() {
    _tripStatusSub = SocketServiceClient.instance.onTripStatus.listen((data) {
      final newStatus = (data['estado'] ?? data['status']) as String?;
      if (newStatus != null && newStatus != _status && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _status = newStatus;
            // Los eventos de socket suelen traer sólo {id, estado}: fusionar con
            // el viaje actual para NO perder conductor / origen / destino.
            final incomingId = data['_id'] ?? data['id'];
            if (_trip == null && incomingId == null) return;
            final current = _trip?.toJson() ?? <String, dynamic>{};
            current['_id'] = current['_id'] ?? incomingId.toString();
            // Fusión segura: un conductor/cliente parcial no pisa el completo.
            final base = Trip.mergeSocketPayload(
                current, Map<String, dynamic>.from(data));
            // `trip:delivered` no existe en el backend: el monto final llega en
            // trip:status_changed (pendiente_confirmacion / finalizado).
            final monto = data['montoFinal'];
            if (monto != null) base['precioFinal'] = num.tryParse(monto.toString());
            _trip = Trip.fromJson(base);
          });
          if (newStatus == TripStatus.finalizado) {
            _showViajeFinalizado();
            return;
          }
          if (newStatus == TripStatus.aceptado || newStatus == TripStatus.enCamino || newStatus == TripStatus.llegada || newStatus == TripStatus.enCurso) {
            _startLocationUpdates();
          }
        });
      }
    });

    _tripCancelledSub = SocketServiceClient.instance.onTripCancelled.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loading = true);
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.popUntil(context, (route) => route.isFirst);
        final msg = mensajeViajeCancelado(data, miRol: ApiClient.instance.rol);
        if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
        if (!mounted) return;
        setState(() => _loading = false);
      });
    });

    _newOfferSub = SocketServiceClient.instance.onNewOffer.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hasOffers = true;
          _ofertas.add(Map<String, dynamic>.from(data));
        });
      });
    });

    _offerAcceptedSub = SocketServiceClient.instance.onOfferAccepted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _offerAcceptedShown) return;
        _offerAcceptedShown = true;
        final conductor = data['conductor'] as Map<String, dynamic>? ?? {};
        _safeReplace(OfertaAceptadaScreen(
          conductorNombre: conductor['nombre'] as String? ?? 'Conductor',
          camion: conductor['tipoVehiculo'] as String? ?? '',
          placa: conductor['placa'] as String? ?? '',
          rating: (conductor['rating'] as num?)?.toDouble() ?? 0,
          onVerSeguimiento: () => Navigator.pop(context),
        ));
      });
    });

    _tripAcceptedSub = SocketServiceClient.instance.onTripAccepted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _status = TripStatus.aceptado);
        _startLocationUpdates();
      });
    });

    _tripStartedSub = SocketServiceClient.instance.onTripStarted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _status = TripStatus.enCurso);
        _startLocationUpdates();
      });
    });

    _driverLocationSub = SocketServiceClient.instance.onDriverLocation.listen((data) {
      final lat = (data['latitude'] ?? data['lat']) as num?;
      final lng = (data['longitude'] ?? data['lng']) as num?;
      if (lat != null && lng != null) {
        final newLat = lat.toDouble();
        final newLng = lng.toDouble();
        if (newLat == _driverLat && newLng == _driverLng) return;
        _driverLat = newLat;
        _driverLng = newLng;
        _scheduleDriverRebuild();
        _checkProximity();
      }
    });

    _finalizeRequestSub = SocketServiceClient.instance.onFinalizeRequest.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pendingFinalizeRequest = Map<String, dynamic>.from(data);
        _showFinalizeConfirmation();
      });
    });

    _tripFinalizedSub = SocketServiceClient.instance.onTripCompleted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showViajeFinalizado();
      });
    });

    _finalizeCancelledSub = SocketServiceClient.instance.onFinalizeCancelled.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_route != null) {
          Navigator.of(context).popUntil((route) => route == _route);
        }
        setState(() {
          _finalizeShown = false;
          _isNavigating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El conductor canceló la solicitud de confirmación')),
        );
      });
    });
  }

  /// `trip:finalized` y `trip:status_changed(finalizado)` llegan ambos: mostrar
  /// la pantalla de viaje finalizado una sola vez.
  void _showViajeFinalizado() {
    if (_finalizedShown || !mounted) return;
    _finalizedShown = true;
    final conductor = _trip?.conductor;
    _safePush(ViajeFinalizado(
      trip: _trip?.toJson() ?? {},
      conductor: conductor?.toJson() ?? {},
    ));
  }

  void _scheduleDriverRebuild() {
    if (!mounted) return;
    final since = DateTime.now().difference(_lastDriverRebuild);
    const minGap = Duration(seconds: 1);
    if (since >= minGap) {
      _lastDriverRebuild = DateTime.now();
      setState(() {});
      return;
    }
    _driverRebuildTimer ??= Timer(minGap - since, () {
      _driverRebuildTimer = null;
      if (!mounted) return;
      _lastDriverRebuild = DateTime.now();
      setState(() {});
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (t) async {
      if (!mounted || _status != TripStatus.buscando) {
        _pollingTimer?.cancel();
        return;
      }
      // Con socket conectado los cambios llegan en tiempo real: sondear sólo
      // cada 15 s como red de seguridad (antes cada 5 s siempre).
      if (SocketServiceClient.instance.isConnected && t.tick % 3 != 0) return;
      try {
        final trip = await TripService.getActiveTrip();
        if (trip != null && mounted) {
          setState(() {
            _trip = Trip.fromJson(trip);
            final estado = _trip?.estado;
            if (estado == TripStatus.aceptado || estado == TripStatus.enCurso) {
              _status = estado!;
              _pollingTimer?.cancel();
            }
          });
        }
      } catch (_) {}
    });
    _startCercanosPolling();
  }

  /// Refresca cada 10 s los vehículos disponibles a <= 2 km del origen mientras se busca conductor.
  void _startCercanosPolling() {
    _cercanosTimer?.cancel();
    _refreshCercanos();
    _cercanosTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshCercanos());
  }

  Future<void> _refreshCercanos() async {
    if (!mounted || _status != TripStatus.buscando || _trip == null) {
      _cercanosTimer?.cancel();
      return;
    }
    // El mapa de vehículos sólo se ve si esta pantalla está al frente.
    if (_route != null && !_route!.isCurrent) return;
    try {
      final cercanos = await TripService.getNearbyDrivers(_trip!.id);
      if (mounted) setState(() => _cercanos = cercanos);
    } catch (_) {}
  }

  void _startFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) { _fallbackPollingTimer?.cancel(); return; }
      if (SocketServiceClient.instance.isConnected) return;
      try {
        final trip = await TripService.getActiveTrip();
        if (trip != null && mounted) {
          final parsed = Trip.fromJson(trip);
          if (parsed.estado != null && parsed.estado != _status) {
            setState(() {
              _trip = parsed;
              _status = parsed.estado!;
            });
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _startLocationUpdates() async {
    // El cliente NO debe publicar su posición en el endpoint de conductores
    // (PUT /api/drivers/location). La posición del conductor llega por socket
    // (driver:location). Esta función queda como no-op para mantener las
    // llamadas existentes.
    _positionSub?.cancel();
  }

  double _distanceToPickup() {
    if (_trip == null) return double.infinity;
    final origen = _trip!.origen;
    if (origen == null) return double.infinity;
    return _haversine(_driverLat, _driverLng, origen.lat, origen.lng) / 1000;
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  void _checkProximity() {
    final dist = _distanceToPickup();
    if (dist < _proximidadKm && !_proximityAlertShown && _status == TripStatus.aceptado) {
      _proximityAlertShown = true;
      _showProximityAlert();
    }
    if (dist < _zonaKm && !_conductorEnLaZonaShown) {
      _conductorEnLaZonaShown = true;
      _showConductorEnLaZona();
    }
  }

  void _showProximityAlert() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DriverNearbyWarningSheet.show(
        context,
        onProceed: () {
          Navigator.maybePop(context);
        },
      );
    });
  }

  void _showConductorEnLaZona() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conductor = _trip?.conductor;
      _safePush(ConductorEnLaZonaScreen(
        conductor: conductor?.toJson() ?? {},
        onChat: () {
          _safePush(ChatScreen(trip: _trip?.toJson() ?? {}));
        },
        onCall: () async {
          final tel = conductor?.telefono;
          if (tel != null) {
            final uri = Uri.parse('tel:$tel');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ));
    });
  }

  Future<void> _doCancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_status == TripStatus.enCurso || _status == TripStatus.llegada) {
        // El backend bloquea la cancelación directa (403) en en_curso y
        // conductor_llegada: ambas requieren solicitud de cancelación.
        await TripService.requestCancellation(_trip?.id ?? '', motivo: 'Cancelado por el usuario');
        messenger.showSnackBar(
          const SnackBar(content: Text('Solicitud de cancelaci\u00f3n enviada. Un administrador la revisar\u00e1.')),
        );
      } else {
        await TripService.cancelTrip(_trip?.id ?? '', motivo: 'Cancelado por el usuario');
        messenger.showSnackBar(
          const SnackBar(content: Text('Viaje cancelado correctamente')),
        );
      }
      if (!mounted) return;
      _safePopUntilFirst();
    } on ApiException catch (e) {
      if (e.code == 'CONDUCTOR_CERCA') {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se puede cancelar: el conductor está a menos de 1 km del origen.')),
        );
      } else if (e.code == 'JUSTIFICACION_REQUERIDA') {
        messenger.showSnackBar(
          SnackBar(content: Text('Justificaci\u00f3n requerida: ${e.message}')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al cancelar: ${e.message}')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al cancelar: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _cancelar() {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => CancelTripScreen(enCurso: _status == TripStatus.enCurso)),
    ).then((result) {
      if (result != null) {
        _doCancel();
      }
    });
  }

  void _showFinalizeConfirmation() {
    if (_finalizeShown) return;
    _finalizeShown = true;
    final conductor = _trip?.conductor;
    final requestData = _pendingFinalizeRequest ?? {};
    final fueraDeRango = requestData['fueraDeRango'] == true;
    final distanciaKm = (requestData['distanciaKm'] as num?)?.toDouble() ?? 0.0;
    final justificacionConductor = requestData['justificacion'] as String?;

    // Primero mostrar LlegadaAlDestinoScreen
    _safePush(LlegadaAlDestinoScreen(
      conductor: conductor?.toJson() ?? {},
      trip: _trip?.toJson() ?? {},
      onVerDetalle: () {
        // Desde aquí ir a ConfirmarEntregaScreen
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ConfirmarEntregaScreen(
            montoFinal: _montoFinalLabel(),
            fueraDeRango: fueraDeRango,
            distanciaKm: distanciaKm,
            justificacionConductor: justificacionConductor,
            onConfirmar: () async {
              _isNavigating = true;
              // Evita que trip:finalized / status 'finalizado' empujen otra
              // pantalla de viaje finalizado mientras confirmamos.
              _finalizedShown = true;
              try {
                final tripId = _trip?.id ?? '';
                if (tripId.isNotEmpty) {
                  await ApiClient.instance.confirmClose(tripId, confirmar: true, idempotencyKey: _confirmCloseKey.keyFor(tripId));
                }
                _confirmCloseKey.settle();
              } on ApiException catch (e) {
                _confirmCloseKey.settle(e);
                // No navegar como si se hubiera confirmado: el usuario puede
                // reintentar (misma clave de idempotencia).
                _isNavigating = false;
                _finalizedShown = false;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al confirmar: ${e.message}')),
                );
                return;
              } catch (e) {
                _confirmCloseKey.settle(e);
                _isNavigating = false;
                _finalizedShown = false;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al confirmar: ${e.toString().replaceFirst("Exception: ", "")}')),
                );
                return;
              }
              // Emitir socket por compatibilidad
              SocketServiceClient.instance.emit('trip:finalize_response', {
                'accepted': true,
                'tripId': _trip?.id,
              });
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => ViajeFinalizado(
                    trip: _trip?.toJson() ?? {},
                    conductor: _trip?.conductor?.toJson() ?? {},
                  ),
                ),
                (route) => route.isFirst,
              );
            },
            onRechazar: (motivo) async {
              _isNavigating = true;
              try {
                final tripId = _trip?.id ?? '';
                if (tripId.isNotEmpty) {
                  await ApiClient.instance.confirmClose(tripId, confirmar: false, motivo: motivo, idempotencyKey: _rejectCloseKey.keyFor('$tripId|$motivo'));
                }
                _rejectCloseKey.settle();
              } on ApiException catch (e) {
                _rejectCloseKey.settle(e);
                _isNavigating = false;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al rechazar: ${e.message}')),
                );
                return;
              } catch (e) {
                _rejectCloseKey.settle(e);
                _isNavigating = false;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al rechazar: ${e.toString().replaceFirst("Exception: ", "")}')),
                );
                return;
              }
              // Emitir socket por compatibilidad
              SocketServiceClient.instance.emit('trip:finalize_response', {
                'accepted': false,
                'motivo': motivo,
                'tripId': _trip?.id,
              });
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => ReportarProblemaScreen(
                    trip: _trip?.toJson(),
                    role: 'cliente',
                    onSubmitted: () {},
                  ),
                ),
                (route) => route.isFirst,
              );
            },
          ),
        ));
      },
    ));
  }

  String _montoFinalLabel() {
    final monto = _trip?.precioFinal ?? _trip?.precioEstimado;
    if (monto == null) return '';
    return 'Monto final: \$${monto.toStringAsFixed(0)}';
  }

  String _formatDistance(double km) {
    if (km.isInfinite) return '--';
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(2)} km';
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cercanosTimer?.cancel();
    _fallbackPollingTimer?.cancel();
    _proximityTimer?.cancel();
    _positionSub?.cancel();
    _tripStatusSub?.cancel();
    _tripCancelledSub?.cancel();
    _newOfferSub?.cancel();
    _offerAcceptedSub?.cancel();
    _tripAcceptedSub?.cancel();
    _tripStartedSub?.cancel();
    _driverLocationSub?.cancel();
    _finalizeRequestSub?.cancel();
    _finalizeCancelledSub?.cancel();
    _tripFinalizedSub?.cancel();
    _connectionSub?.cancel();
    _driverRebuildTimer?.cancel();
    if (_trip != null) {
      SocketServiceClient.instance.leaveTrip(_trip!.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(),
    );
  }

  String _getAppBarTitle() {
    switch (_status) {
      case TripStatus.buscando:
        return 'Buscando conductor';
      case TripStatus.aceptado:
        return 'Conductor asignado';
      case TripStatus.enCamino:
        return 'Conductor en camino';
      case TripStatus.llegada:
        return 'Conductor llegó';
      case TripStatus.enCurso:
        return 'Viaje en curso';
      case TripStatus.entregado:
        return 'Viaje entregado';
      case TripStatus.esperaConfirmacion:
      case TripStatus.pendienteConfirmacion:
        return 'Viaje completado';
      case TripStatus.finalizado:
        return 'Viaje finalizado';
      case TripStatus.disputa:
      case TripStatus.enDisputa:
        return 'Viaje en disputa';
      case TripStatus.cancelado:
        return 'Viaje cancelado';
      case TripStatus.rechazado:
        return 'Viaje rechazado';
      case TripStatus.sos:
        return 'Emergencia activa';
      case TripStatus.reservado:
        return 'Reserva programada';
      default:
        return 'Rastreo';
    }
  }

  List<Widget> _buildAppBarActions() {
    if (_hasOffers && _status == TripStatus.buscando) {
      return [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.local_offer, color: Color(0xFF1A1A2E)),
              tooltip: 'Ver ofertas',
              onPressed: _verOfertas,
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_ofertas.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ];
    }
    return [];
  }

  Widget _buildBody() {
    if (_loading && _trip == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (rastreoVistaPara(_status)) {
      case RastreoVista.busqueda:
        return _buildSearchContent();
      case RastreoVista.seguimiento:
        return _buildTrackingContent();
      case RastreoVista.entrega:
        return _buildDeliveryContent();
      case RastreoVista.disputa:
        return RastreoEstadoInfo(
          icon: Icons.gavel_rounded,
          color: const Color(0xFFF59E0B),
          titulo: 'Viaje en disputa',
          mensaje: 'Un moderador está revisando el caso. Te notificaremos '
              'la resolución; mientras tanto no necesitas hacer nada más.',
          onSoporte: () => _safePush(const SoporteScreen()),
          onInicio: _volverAlInicio,
        );
      case RastreoVista.cerrado:
        final rechazado = _status == TripStatus.rechazado;
        return RastreoEstadoInfo(
          icon: Icons.cancel_outlined,
          color: const Color(0xFFDC2626),
          titulo: rechazado ? 'Viaje rechazado' : 'Viaje cancelado',
          mensaje: 'Este viaje ya no está activo. Puedes solicitar uno nuevo '
              'desde el inicio.',
          onSoporte: () => _safePush(const SoporteScreen()),
          onInicio: _volverAlInicio,
        );
      case RastreoVista.reserva:
        return RastreoEstadoInfo(
          icon: Icons.event_available,
          color: const Color(0xFF2563EB),
          titulo: 'Reserva programada',
          mensaje: 'La búsqueda de conductor comenzará a la hora programada.',
          onInicio: _volverAlInicio,
        );
    }
  }

  void _volverAlInicio() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildDeliveryContent() {
    if (_status == TripStatus.esperaConfirmacion || _status == TripStatus.pendienteConfirmacion) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 80, color: Color(0xFFF59E0B)),
              const SizedBox(height: 24),
              const Text(
                'Esperando confirmación',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 8),
              const Text(
                'El conductor ha solicitado la confirmación de entrega.\nRevisa la carga y confirma en la pantalla de confirmación.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showFinalizeConfirmation(),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Ir a confirmación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF2563EB)),
            const SizedBox(height: 24),
            const Text(
              'Viaje completado',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Text(
              'Estado: ${_getAppBarTitle()}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Mapa de búsqueda: radio de 2 km alrededor del origen, pulso y vehículos
  /// disponibles cercanos.
  Widget _buildNearbyMap() {
    final origen = _trip?.origen;
    if (origen == null) {
      return ColoredBox(
        color: const Color(0xFFEFF4FF),
        child: Center(child: _buildPulseAnimation()),
      );
    }
    final centro = LatLng(origen.lat, origen.lng);
    if (_nearbyMapCenter != centro) {
      _nearbyMapCenter = centro;
      _nearbyMapOptions = MapOptions(initialCenter: centro, initialZoom: 13.5);
    }
    return FlutterMap(
      options: _nearbyMapOptions!,
      children: [
        _tileLayer,
        CircleLayer(circles: [
          CircleMarker(
            point: centro,
            radius: 2000,
            useRadiusInMeter: true,
            color: const Color(0x142563EB),
            borderColor: const Color(0x662563EB),
            borderStrokeWidth: 1.5,
          ),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: centro,
            width: 140,
            height: 140,
            child: const PulsoBusqueda(size: 140),
          ),
          for (final c in _cercanos)
            Marker(
              point: LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble()),
              width: 34,
              height: 34,
              child: const Icon(Icons.local_shipping, color: Color(0xFF1A1A2E), size: 28),
            ),
          Marker(
            point: centro,
            width: 36,
            height: 36,
            alignment: Alignment.topCenter,
            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
          ),
        ]),
      ],
    );
  }

  /// Inicio de la búsqueda: creación del viaje o, si no se conoce, la
  /// apertura de esta pantalla.
  DateTime get _inicioBusqueda {
    final creado = DateTime.tryParse(_trip?.createdAt ?? '');
    if (creado != null && creado.isBefore(DateTime.now())) return creado;
    return _pantallaAbierta;
  }

  void _verOfertas() {
    _safePush(OfertasRecibidasScreen(
      ofertas: _ofertas,
      tripId: _trip?.id,
      trip: _trip?.toJson() ?? {},
      onAccept: (offerId) async {
        await OfferService.acceptOffer(_trip?.id, offerId);
      },
      onReject: (offerId) async {
        await OfferService.rejectOffer(_trip?.id, offerId);
      },
    ));
  }

  Future<void> _cancelarBusqueda() async {
    if (_cancelling) return;
    if (await confirmarCancelarBusqueda(context)) _doCancel();
  }

  Widget _buildSearchContent() {
    return BusquedaConductorView(
      trip: _trip,
      mapa: _buildNearbyMap(),
      vehiculosCercanos: _cercanos.length,
      ofertas: _ofertas.length,
      cancelando: _cancelling,
      inicioBusqueda: _inicioBusqueda,
      onVerOfertas: _verOfertas,
      onCancelar: _cancelarBusqueda,
    );
  }

  Widget _buildPulseAnimation() => const _PulseSearchIndicator();

  Widget _buildTrackingContent() {
    return Stack(
      children: [
        Container(color: const Color(0xFFE5E7EB)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildDriverPanel(),
        ),
      ],
    );
  }

  Widget _buildDriverPanel() {
    final conductor = _trip?.conductor;
    final conductorNombre = conductor?.nombre ?? 'Conductor';
    final rating = conductor?.calificacion ?? 0;
    final telefono = conductor?.telefono;
    final distance = _distanceToPickup();
    // Backend: el chat del viaje solo es válido en aceptado/en_curso (422 fuera).
    final chatEnabled = _status == TripStatus.aceptado || _status == TripStatus.enCurso;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE5E7EB),
                child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conductorNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
              if (rating > 0)
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(Icons.access_time, '5 min'),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.location_on, _formatDistance(distance)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (chatEnabled) ...[
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    onTap: () {
                      _safePush(ChatScreen(trip: _trip?.toJson() ?? {}));
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone_outlined,
                  label: 'Llamar',
                  onTap: () async {
                    if (telefono != null) {
                      final uri = Uri.parse('tel:$telefono');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelar',
                  onTap: _cancelling ? null : _cancelar,
                  color: const Color(0xFFE53935),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.pending_actions_outlined,
                  label: 'Reportar',
                  onTap: () {
                    _safePush(ReportarProblemaScreen(
                      trip: _trip?.toJson(),
                      role: 'cliente',
                      onSubmitted: () {
                        _safePop();
                      },
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'SOS',
                  onTap: _sosSending ? null : _sendSos,
                  color: const Color(0xFFDC2626),
                  showSpinner: _sosSending,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
    bool showSpinner = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            if (showSpinner)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
              )
            else
              Icon(icon, color: color ?? const Color(0xFF2563EB), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color ?? const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSos() async {
    if (_sosSending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar alerta SOS'),
        content: const Text(
          'Se notificará a tu contacto de emergencia con tu ubicación actual. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sosSending = true);
    try {
      final alerta = await SosService.sendAlert(tripId: _trip?.id, motivo: 'SOS enviado por el cliente');
      if (!mounted) return;
      if (alerta.id != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmergenciaChatScreen(alertaId: alerta.id),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta SOS enviada. Se te contactará pronto.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar SOS: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    } finally {
      if (mounted) setState(() => _sosSending = false);
    }
  }
}

/// Animación de "buscando". Tiene su propio AnimationController que sólo
/// existe mientras se muestra: antes el controlador de la pantalla repetía
/// sin fin (60 fps) durante TODO el viaje aunque la animación no se viera.
class _PulseSearchIndicator extends StatefulWidget {
  const _PulseSearchIndicator();

  @override
  State<_PulseSearchIndicator> createState() => _PulseSearchIndicatorState();
}

class _PulseSearchIndicatorState extends State<_PulseSearchIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2563EB),
          ),
          child: const Icon(Icons.search, color: Colors.white, size: 28),
        ),
        builder: (ctx, child) {
          return SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(3, (i) {
                  final phase = (_pulseCtrl.value + i / 3) % 1.0;
                  return Transform.scale(
                    scale: 0.5 + phase * 0.8,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35 - phase * 0.3),
                      ),
                    ),
                  );
                }),
                child!,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Qué contenido muestra [RastreoScreen] para cada estado del backend
/// (`app/services/trip_state_machine.ts`). Ningún estado terminal o
/// desconocido cae en la vista de "Buscando conductor".
enum RastreoVista { busqueda, seguimiento, entrega, disputa, cerrado, reserva }

@visibleForTesting
RastreoVista rastreoVistaPara(String status) {
  switch (status) {
    case TripStatus.creado:
    case TripStatus.buscando:
    case TripStatus.pendiente:
      return RastreoVista.busqueda;
    case TripStatus.aceptado:
    case TripStatus.enCamino:
    case TripStatus.llegada:
    case TripStatus.enCurso:
    case TripStatus.sos:
      return RastreoVista.seguimiento;
    case TripStatus.entregado:
    case TripStatus.esperaConfirmacion:
    case TripStatus.pendienteConfirmacion:
    case TripStatus.finalizado:
      return RastreoVista.entrega;
    case TripStatus.disputa:
    case TripStatus.enDisputa:
      return RastreoVista.disputa;
    case TripStatus.cancelado:
    case TripStatus.rechazado:
      return RastreoVista.cerrado;
    case TripStatus.reservado:
      return RastreoVista.reserva;
    default:
      // Estado nuevo aún no contemplado: mejor el seguimiento del viaje que
      // una búsqueda engañosa.
      return RastreoVista.seguimiento;
  }
}

/// Panel informativo de estado (disputa, cancelado, reserva) con acciones
/// para salir de la pantalla: contactar a soporte y volver al inicio.
class RastreoEstadoInfo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String mensaje;
  final VoidCallback? onSoporte;
  final VoidCallback onInicio;

  const RastreoEstadoInfo({
    super.key,
    required this.icon,
    required this.color,
    required this.titulo,
    required this.mensaje,
    required this.onInicio,
    this.onSoporte,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 24),
            Text(
              titulo,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onSoporte != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSoporte,
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Contactar a soporte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onInicio,
                icon: const Icon(Icons.home_outlined),
                label: const Text('Volver al inicio'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
