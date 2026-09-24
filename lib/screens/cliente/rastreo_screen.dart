import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/trip.dart';
import '../../contracts/calificacion.dart';
import '../../contracts/cancelacion.dart';
import '../../contracts/trip_status.dart';
import '../../services/api/trip_service.dart';
import '../../services/api/offer_service.dart';
import '../../services/api/http_client.dart';
import '../../services/api_client.dart';
import '../../services/config_cliente_service.dart';
import '../../services/map_config.dart';
import '../../services/route_service.dart';
import '../../services/socket_service_client.dart';
import '../../services/sos_service.dart';
import '../../widgets/driver_nearby_warning_sheet.dart';
import '../../widgets/capa_vehiculos.dart';
import '../../widgets/mapa_viaje.dart';
import '../../widgets/vehiculo_mapa.dart';
import '../shared/action_key.dart';
import 'busqueda_conductor_view.dart';
import 'cancel_trip_screen.dart';
import 'nuevo_envio_screen.dart';
import 'ofertas_recibidas_screen.dart';
import 'oferta_aceptada_screen.dart';
import 'confirmar_entrega_screen.dart';
import 'disputa_creada_screen.dart';
import 'viaje_finalizado.dart';
import 'reportar_problema_screen.dart';
import 'rastreo_ui.dart';
import 'seguimiento_viaje_view.dart';
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
  static const double _zonaKm = 0.05;
  Trip? _trip;
  final List<Map<String, dynamic>> _ofertas = [];
  String _status = TripStatus.buscando;
  bool _loading = false;
  bool _cancelling = false;
  bool _hasOffers = false;
  bool _offerAcceptedShown = false;
  // Celebración "¡Oferta aceptada!" abierta encima del rastreo.
  Route<void>? _celebracionRoute;
  Timer? _celebracionTimer;
  bool _finalizeShown = false;
  bool _finalizedShown = false;
  // El viaje quedó cancelado porque BUSQUEDA_TIMEOUT_MIN se venció sin
  // ofertas aceptadas (BusquedaTimeoutService): la vista de cierre debe
  // decirlo, no mostrar el aviso genérico de "viaje cancelado".
  bool _canceladoPorSistema = false;
  int _minutosBusqueda = busquedaTimeoutMinPorDefecto;
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
  StreamSubscription<Map<String, dynamic>>? _etaSub;
  // Última ETA (min) enviada por el backend en `trip:eta_update`.
  int? _etaServidorMin;
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
  // El conductor ya está dentro del radio de aviso: cancelar desde ahora
  // pide confirmación (no se interrumpe al cliente sin que lo pida).
  bool _conductorCerca = false;
  // Ruta de "Conductor en la zona", para cerrarla cuando el viaje arranca.
  Route<void>? _zonaRoute;
  bool _conductorEnLaZonaShown = false;
  double _driverLat = 0;
  double _driverLng = 0;
  // Rumbo del GPS si el payload lo trae (hoy el backend sólo reenvía lat/lng:
  // el mapa lo calcula del movimiento).
  double? _driverRumbo;
  // Throttle de reconstrucciones por `driver:location` (máx. 1 por segundo).
  DateTime _lastDriverRebuild = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _driverRebuildTimer;
  Map<String, dynamic>? _pendingFinalizeRequest;
  final DateTime _pantallaAbierta = DateTime.now();
  // Mapa de búsqueda: tiles y opciones creados una vez, no en cada build().
  late final TileLayer _tileLayer = TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app');
  MapOptions? _nearbyMapOptions;
  LatLng? _nearbyMapCenter;
  // Seguimiento: ruta dibujada (geometría del servicio de rutas) y cámara.
  List<LatLng>? _ruta;
  String? _rutaDeClave;
  String? _rutaClave;
  DateTime? _rutaPedidaEn;
  bool _seguirCamara = true;

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
    // Reglas del backend (radio de cierre, plazo de confirmación); no bloquea.
    ConfigClienteService.instance.cargar();

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

      if (_trip != null && !_buscando) {
        await _startLocationUpdates();
      }

      if (_buscando && mounted) {
        _startPolling();
        _cargarOfertasExistentes();
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

  void _agregarOfertas(List<Map<String, dynamic>> nuevas) {
    final merged = fusionarOfertas(_ofertas, nuevas);
    setState(() {
      _ofertas
        ..clear()
        ..addAll(merged);
      _hasOffers = _ofertas.isNotEmpty;
    });
  }

  /// Las ofertas llegan por socket sólo mientras la pantalla está abierta: al
  /// abrirla con la búsqueda ya en marcha, traer las que ya existen.
  Future<void> _cargarOfertasExistentes() async {
    final tripId = _trip?.id;
    if (tripId == null || tripId.isEmpty) return;
    try {
      final ofertas = await OfferService.getOffers(tripId);
      if (!mounted || ofertas.isEmpty) return;
      _agregarOfertas(ofertas);
    } catch (e) {
      // No bloquea: las nuevas ofertas siguen llegando por socket y la
      // pantalla de ofertas vuelve a consultarlas.
      debugPrint('Rastreo: no se pudieron cargar las ofertas: $e');
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

  /// Cierra las pantallas abiertas encima del rastreo (ofertas, chat,
  /// celebración…) para que la siguiente pantalla del flujo quede al frente.
  void _volverARastreo() {
    final route = _route;
    if (!mounted || route == null || !route.isActive || route.isCurrent) return;
    Navigator.of(context).popUntil((r) => r == route);
    _isNavigating = false;
  }

  /// "¡Oferta aceptada!" se muestra ENCIMA del rastreo (no lo reemplaza):
  /// el rastreo sigue vivo con sus sockets y sondeos, así la confirmación de
  /// entrega aparece aunque el cliente nunca toque "Ver seguimiento". Se
  /// cierra sola a los pocos segundos o cuando el viaje avanza.
  void _mostrarOfertaAceptada(Map<String, dynamic> conductor) {
    if (!mounted || _offerAcceptedShown) return;
    _offerAcceptedShown = true;
    if (rastreoVistaPara(_status) == RastreoVista.busqueda) {
      setState(() => _status = TripStatus.aceptado);
    }
    _volverARastreo();
    final route = MaterialPageRoute<void>(
      builder: (_) => OfertaAceptadaScreen.desdeConductor(
        conductor,
        onVerSeguimiento: _cerrarCelebracion,
      ),
    );
    _celebracionRoute = route;
    Navigator.of(context).push(route).whenComplete(() {
      if (_celebracionRoute == route) {
        _celebracionRoute = null;
        _celebracionTimer?.cancel();
      }
    });
    _celebracionTimer?.cancel();
    _celebracionTimer = Timer(duracionCelebracionOferta, _cerrarCelebracion);
    // Los eventos de socket traen poco del conductor: traer el viaje completo.
    _refrescarViaje();
  }

  void _cerrarCelebracion() {
    _celebracionTimer?.cancel();
    _celebracionTimer = null;
    final route = _celebracionRoute;
    _celebracionRoute = null;
    if (route == null || !mounted || !route.isActive) return;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  Future<void> _refrescarViaje() async {
    try {
      final data = await TripService.getActiveTrip();
      if (data == null || !mounted) return;
      final parsed = Trip.fromJson(data);
      final anterior = _status;
      setState(() {
        _trip = parsed;
        final estado = parsed.estado;
        // No retroceder a la búsqueda si el backend aún no reflejó la aceptación.
        if (estado != null && rastreoVistaPara(estado) != RastreoVista.busqueda) {
          _status = estado;
        }
      });
      if (_status != anterior) _alCambiarEstado(_status);
    } catch (e) {
      debugPrint('Rastreo: no se pudo refrescar el viaje: $e');
    }
  }

  /// Reacción de la pantalla a un nuevo estado del viaje, venga del socket o
  /// de un sondeo: la solicitud de confirmación y el cierre se muestran
  /// siempre, esté el cliente donde esté dentro del flujo del viaje.
  void _alCambiarEstado(String estado) {
    if (!mounted) return;
    if (estado == TripStatus.finalizado) {
      _showViajeFinalizado();
      return;
    }
    if (estado == TripStatus.pendienteConfirmacion || estado == TripStatus.esperaConfirmacion) {
      _showFinalizeConfirmation();
      return;
    }
    if (rastreoVistaPara(estado) != RastreoVista.busqueda && estado != TripStatus.aceptado) {
      _cerrarCelebracion();
    }
    if (estado == TripStatus.enCurso || estado == TripStatus.sos) _cerrarConductorEnLaZona();
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
          _alCambiarEstado(newStatus);
          if (newStatus == TripStatus.finalizado) return;
          if (newStatus == TripStatus.aceptado || newStatus == TripStatus.enCamino || newStatus == TripStatus.llegada || newStatus == TripStatus.enCurso) {
            _startLocationUpdates();
          }
        });
      }
    });

    _tripCancelledSub = SocketServiceClient.instance.onTripCancelled.listen((data) {
      // Sin conductor tras BUSQUEDA_TIMEOUT_MIN: se queda en esta pantalla
      // con el aviso honesto y las acciones para reintentar (no se saca al
      // cliente con un snackbar genérico de "viaje cancelado").
      if (esCanceladoPorSistema(
        canceladoPor: data['canceladoPor']?.toString(),
        motivo: data['motivo']?.toString(),
      )) {
        _mostrarCanceladoPorSistema(data);
        return;
      }
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
        _agregarOfertas([Map<String, dynamic>.from(data)]);
      });
    });

    _offerAcceptedSub = SocketServiceClient.instance.onOfferAccepted.listen((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final conductor = data['conductor'] is Map
            ? Map<String, dynamic>.from(data['conductor'] as Map)
            : <String, dynamic>{};
        _mostrarOfertaAceptada(conductor);
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
        _driverRumbo = rumboDePayload(data);
        _scheduleDriverRebuild();
        _checkProximity();
      }
    });

    _etaSub = SocketServiceClient.instance.onTripEtaUpdate.listen((data) {
      final minutos = minutosEta(data);
      if (minutos == null || minutos == _etaServidorMin || !mounted) return;
      setState(() => _etaServidorMin = minutos);
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
    _cerrarCelebracion();
    _volverARastreo();
    _isNavigating = true;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ViajeFinalizado(
        trip: _trip?.toJson() ?? {},
        conductor: conductor?.toJson() ?? {},
      ),
    )).whenComplete(() => _isNavigating = false);
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
      if (!mounted || !_buscando) {
        _pollingTimer?.cancel();
        return;
      }
      // Con socket conectado los cambios llegan en tiempo real: sondear sólo
      // cada 15 s como red de seguridad (antes cada 5 s siempre).
      if (SocketServiceClient.instance.isConnected && t.tick % 3 != 0) return;
      try {
        final trip = await TripService.getActiveTrip();
        if (trip != null && mounted) {
          String? nuevo;
          setState(() {
            _trip = Trip.fromJson(trip);
            final estado = _trip?.estado;
            if (estado != null && estado != _status &&
                rastreoVistaPara(estado) != RastreoVista.busqueda) {
              _status = estado;
              nuevo = estado;
              _pollingTimer?.cancel();
            }
          });
          if (nuevo != null) _alCambiarEstado(nuevo!);
        } else if (trip == null && mounted && _trip != null) {
          // GET /api/trips/active ya no lo devuelve como activo: puede que
          // BusquedaTimeoutService lo haya cancelado y se perdiera el socket
          // (pantalla en segundo plano, reconexión...).
          await _detectarCancelacionAlSondear();
        }
      } catch (_) {}
    });
    _startCercanosPolling();
  }

  /// Confirma por qué el viaje dejó de estar activo cuando el sondeo lo nota
  /// antes que el socket: si fue BusquedaTimeoutService, mismo aviso honesto
  /// que si hubiera llegado por `trip:cancelled`.
  Future<void> _detectarCancelacionAlSondear() async {
    final tripId = _trip?.id;
    if (tripId == null) return;
    try {
      final detalle = await TripService.getTripDetail(tripId);
      if (!mounted || detalle['estado'] != TripStatus.cancelado) return;
      final motivo = detalle['motivoCancelacion'] as String?;
      if (esCanceladoPorSistema(motivo: motivo)) {
        _mostrarCanceladoPorSistema(const {});
      } else if (mounted) {
        setState(() => _status = TripStatus.cancelado);
      }
    } catch (_) {}
  }

  /// Refresca cada 10 s los vehículos disponibles a <= 2 km del origen mientras se busca conductor.
  void _startCercanosPolling() {
    _cercanosTimer?.cancel();
    _refreshCercanos();
    _cercanosTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshCercanos());
  }

  Future<void> _refreshCercanos() async {
    if (!mounted || !_buscando || _trip == null) {
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
    _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      if (!mounted) { _fallbackPollingTimer?.cancel(); return; }
      // Sin socket, cada 10 s; con socket, cada 30 s como red de seguridad
      // por si se perdió un evento (p. ej. la solicitud de confirmación).
      if (SocketServiceClient.instance.isConnected && t.tick % 3 != 0) return;
      try {
        final trip = await TripService.getActiveTrip();
        if (trip != null && mounted) {
          final parsed = Trip.fromJson(trip);
          final estado = parsed.estado;
          if (estado != null && estado != _status) {
            setState(() {
              _trip = parsed;
              _status = estado;
            });
            _alCambiarEstado(estado);
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

  /// Distancia del conductor al origen; infinita mientras no llegue su
  /// posición por socket (antes se medía desde 0,0).
  double _distanceToPickup() {
    if (_trip == null) return double.infinity;
    if (_driverLat == 0 && _driverLng == 0) return double.infinity;
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
    // El backend penaliza la cancelación del cliente en aceptado y
    // conductor_en_camino: avisar en ambos.
    final cancelarPenaliza = _status == TripStatus.aceptado || _status == TripStatus.enCamino;
    // Radio del backend (GET /api/config/cliente); 1 km si no está.
    final proximidadKm = ConfigClienteService.instance.actual.radioAvisoConductorCercaKm;
    if (dist < proximidadKm && cancelarPenaliza) _conductorCerca = true;
    if (dist < _zonaKm && !_conductorEnLaZonaShown) {
      _conductorEnLaZonaShown = true;
      _showConductorEnLaZona();
    }
  }

  void _showConductorEnLaZona() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isNavigating) return;
      final conductor = _trip?.conductor;
      _isNavigating = true;
      final route = MaterialPageRoute<void>(builder: (_) => ConductorEnLaZonaScreen(
        conductor: conductor?.toJson() ?? {},
        origen: MapaViaje.punto(_trip?.origen?.lat, _trip?.origen?.lng),
        ubicacionConductor: MapaViaje.punto(_driverLat, _driverLng),
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
      _zonaRoute = route;
      Navigator.of(context).push(route).whenComplete(() {
        _isNavigating = false;
        if (_zonaRoute == route) _zonaRoute = null;
      });
    });
  }

  /// "Conductor en la zona" sólo tiene sentido antes de recoger la carga: al
  /// iniciar el viaje se cierra para que el cliente vea el seguimiento.
  void _cerrarConductorEnLaZona() {
    final route = _zonaRoute;
    if (route == null || !route.isActive || !mounted) return;
    _zonaRoute = null;
    Navigator.of(context).removeRoute(route);
    _isNavigating = false;
  }

  Future<void> _doCancel({String? motivo}) async {
    if (_cancelling) return;
    final motivoFinal = (motivo == null || motivo.trim().isEmpty) ? 'Cancelado por el usuario' : motivo.trim();
    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (cancelacionRequiereSolicitud(_status)) {
        await TripService.requestCancellation(_trip?.id ?? '', motivo: motivoFinal);
        messenger.showSnackBar(
          const SnackBar(content: Text('Solicitud de cancelaci\u00f3n enviada. Un administrador la revisar\u00e1.')),
        );
      } else {
        await TripService.cancelTrip(_trip?.id ?? '', motivo: motivoFinal);
        messenger.showSnackBar(
          const SnackBar(content: Text('Viaje cancelado correctamente')),
        );
      }
      if (!mounted) return;
      _safePopUntilFirst();
    } on ApiException catch (e) {
      if (e.code == 'CONDUCTOR_CERCA') {
        // El radio es configurable en el backend: su mensaje ya trae la
        // distancia y el mínimo.
        final km = (e.data?['distanciaKm'] as num?)?.toStringAsFixed(2);
        final msg = e.message.isNotEmpty
            ? e.message
            : 'No se puede cancelar: el conductor está cerca del origen${km != null ? ' ($km km)' : ''}.';
        messenger.showSnackBar(SnackBar(content: Text(msg)));
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
    // Con el conductor cerca, cancelar puede penalizar: se avisa antes (el
    // backend decide al final si aún se puede, CONDUCTOR_CERCA).
    final penaliza = _status == TripStatus.aceptado || _status == TripStatus.enCamino;
    if (_conductorCerca && penaliza) {
      DriverNearbyWarningSheet.show(context, onProceed: _abrirCancelacion);
      return;
    }
    _abrirCancelacion();
  }

  void _abrirCancelacion() {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => CancelTripScreen(enCurso: cancelacionRequiereSolicitud(_status))),
    ).then((result) {
      final motivo = motivoDesdeResultado(result);
      if (motivo != null) _doCancel(motivo: motivo);
    });
  }

  void _showFinalizeConfirmation() {
    if (_finalizeShown || !mounted) return;
    _finalizeShown = true;
    final conductor = _trip?.conductor;
    // La celebración, el chat o cualquier otra pantalla del viaje no deben
    // tapar la solicitud de confirmación.
    _cerrarCelebracion();
    _volverARastreo();
    _isNavigating = true;

    // La foto de evidencia puede no estar aún en `_trip` (el conductor la
    // sube justo antes de pedir la finalización y el socket puede llegar
    // antes de que se refresque el viaje): se completa con lo que traiga
    // `trip:finalize_request` si `_trip` todavía no la tiene.
    final tripParaLlegada = Map<String, dynamic>.from(_trip?.toJson() ?? {});
    final fotoPendiente = _pendingFinalizeRequest?['foto'] as String?;
    final fotoActual = tripParaLlegada['fotoEntrega'] as String?;
    if ((fotoActual == null || fotoActual.isEmpty) && fotoPendiente != null && fotoPendiente.isNotEmpty) {
      tripParaLlegada['fotoEntrega'] = fotoPendiente;
    }

    // Primero mostrar LlegadaAlDestinoScreen
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LlegadaAlDestinoScreen(
      conductor: conductor?.toJson() ?? {},
      trip: tripParaLlegada,
      ubicacionConductor: MapaViaje.punto(_driverLat, _driverLng),
      cargarFoto: _trip?.id == null
          ? null
          : () async => (await TripService.getTripDetail(_trip!.id))['fotoEntrega'] as String?,
      onVerDetalle: () {
        // Los datos de `trip:finalize_request` pueden llegar después del
        // cambio de estado: se leen al abrir la confirmación.
        final requestData = _pendingFinalizeRequest ?? {};
        final fueraDeRango = requestData['fueraDeRango'] == true;
        final distanciaKm = (requestData['distanciaKm'] as num?)?.toDouble() ?? 0.0;
        final justificacionConductor = requestData['justificacion'] as String?;
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
              Map<String, dynamic>? respuesta;
              try {
                final tripId = _trip?.id ?? '';
                if (tripId.isNotEmpty) {
                  respuesta = await ApiClient.instance.confirmClose(tripId, confirmar: false, motivo: motivo, idempotencyKey: _rejectCloseKey.keyFor('$tripId|$motivo'));
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
              // El backend ya creó (o reutilizó) la disputa al rechazar y dejó
              // el viaje en 'disputa': no se abre otra con POST /api/disputes
              // (siempre fallaría). Se muestra la disputa del backend.
              final disputaId = respuesta?['disputaId']?.toString();
              final numero = await _numeroDisputa(disputaId);
              if (!mounted) return;
              final navigator = Navigator.of(context);
              if (disputaId == null || disputaId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Rechazaste la entrega. Un moderador revisará el caso.'),
                ));
                navigator.popUntil((route) => route.isFirst);
                return;
              }
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => DisputaCreadaScreen(disputeNumber: numero, disputeId: disputaId),
                ),
                (route) => route.isFirst,
              );
            },
          ),
        ));
      },
    ))).whenComplete(() {
      // Si el cliente vuelve atrás sin responder, "Ir a confirmación" y una
      // nueva solicitud pueden volver a abrirla.
      _isNavigating = false;
      _finalizeShown = false;
    });
  }

  /// Número visible de la disputa (GET /api/disputes/:id); si no se puede
  /// consultar se muestra su id real.
  Future<String> _numeroDisputa(String? disputaId) async {
    if (disputaId == null || disputaId.isEmpty) return '—';
    try {
      final d = await ApiClient.instance.getDispute(disputaId);
      final numero = d['numero']?.toString().trim();
      if (numero != null && numero.isNotEmpty) return numero;
    } catch (e) {
      debugPrint('Rastreo: no se pudo leer la disputa $disputaId: $e');
    }
    return '#$disputaId';
  }

  String _montoFinalLabel() {
    final monto = _trip?.precioFinal ?? _trip?.precioEstimado;
    if (monto == null) return '';
    final miles = monto.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return 'Monto final: \$$miles';
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
    _celebracionTimer?.cancel();
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
    _etaSub?.cancel();
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
    // Buscando conductor y viaje en curso: el mapa ocupa toda la pantalla y
    // la barra superior flota encima (la dibuja cada vista).
    final vista = rastreoVistaPara(_status);
    final pantallaCompleta = !(_loading && _trip == null) &&
        (vista == RastreoVista.busqueda || vista == RastreoVista.seguimiento);
    if (pantallaCompleta) {
      return Scaffold(
        backgroundColor: RastreoColores.fondo,
        body: _buildBody(),
      );
    }
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
      ),
      body: _buildBody(),
    );
  }

  /// Aún sin conductor: `buscando_conductor`, o `pendiente` en cuanto llega
  /// la primera oferta (el backend cambia el estado al recibirla).
  bool get _buscando => rastreoVistaPara(_status) == RastreoVista.busqueda;

  String _getAppBarTitle() {
    switch (_status) {
      case TripStatus.creado:
      case TripStatus.buscando:
      case TripStatus.pendiente:
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

  /// Acceso a las ofertas en la barra flotante, con su contador.
  List<Widget> _accionesBusqueda() {
    if (!(_hasOffers && _buscando)) return const [];
    return [
      BotonFlotanteRastreo(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.local_offer_outlined, color: RastreoColores.primario),
              tooltip: 'Ver ofertas',
              onPressed: _verOfertas,
            ),
            Positioned(
              right: 4,
              top: 4,
              // El contador tapa parte del icono: que no absorba el toque.
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RastreoColores.rojo,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
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
            ),
          ],
        ),
      ),
    ];
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
        if (_canceladoPorSistema) {
          final aviso = avisoSinConductor(minutos: _minutosBusqueda);
          return RastreoEstadoInfo(
            icon: Icons.search_off_rounded,
            color: const Color(0xFFDC2626),
            titulo: aviso.titulo,
            mensaje: aviso.mensaje,
            accionPrimariaTexto: 'Intentar de nuevo',
            accionPrimariaIcon: Icons.refresh_rounded,
            onAccionPrimaria: _reintentarEnvio,
            onInicio: _volverAlInicio,
          );
        }
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
          // reservado -> cancelado está permitido (trip_state_machine.ts).
          textoCancelar: 'Cancelar reserva',
          onCancelar: _cancelling ? null : _cancelar,
        );
    }
  }

  void _volverAlInicio() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Muestra el aviso honesto de "sin conductor" (BusquedaTimeoutService)
  /// en esta misma pantalla, en vez de sacar al cliente con un snackbar
  /// genérico. Llega por el socket `trip:cancelled` o, si se perdió el
  /// evento, al detectarlo en un sondeo ([_detectarCancelacionAlSondear]).
  void _mostrarCanceladoPorSistema(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cerrarCelebracion();
      _volverARastreo();
      setState(() {
        _status = TripStatus.cancelado;
        _canceladoPorSistema = true;
        _minutosBusqueda = minutosBusquedaDesde(data);
      });
    });
  }

  /// "Intentar de nuevo": abre un envío nuevo. `NuevoEnvioScreen` recupera
  /// origen/destino/carga del borrador que se guarda mientras se escribe
  /// (no se borró al solicitar este viaje), así que quedan precargados.
  void _reintentarEnvio() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NuevoEnvioScreen()),
    );
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

  /// Mapa de búsqueda a pantalla completa: radio de 2 km alrededor del
  /// origen, pulso y vehículos disponibles cercanos. La cámara encuadra el
  /// radio por encima de la tarjeta inferior.
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
      final media = MediaQuery.of(context);
      // Radio de búsqueda + un margen, en grados.
      const radioKm = 2.2;
      final dLat = radioKm / 110.574;
      final dLng = radioKm / (111.320 * cos(_toRad(origen.lat)).abs().clamp(0.01, 1.0));
      _nearbyMapOptions = MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(origen.lat - dLat, origen.lng - dLng),
            LatLng(origen.lat + dLat, origen.lng + dLng),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            media.padding.top + 72,
            16,
            media.size.height * 0.6, // la hoja de búsqueda cubre ~60 % de la pantalla
          ),
        ),
      );
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
        ]),
        CapaVehiculos(
          vehiculos: vehiculosCercanosEnMapa(_cercanos),
          // /nearby-drivers redondea a ~11 m: sólo un avance claro gira el vehículo.
          umbralRumboM: 30,
        ),
        MarkerLayer(markers: [
          Marker(
            point: centro,
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: const Icon(Icons.location_on, color: RastreoColores.rojo, size: 40),
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
    if (_isNavigating) return;
    _isNavigating = true;
    Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => OfertasRecibidasScreen(
      ofertas: _ofertas,
      tripId: _trip?.id,
      trip: _trip?.toJson() ?? {},
      onAccept: (offerId) async {
        await OfferService.acceptOffer(_trip?.id, offerId);
      },
      onReject: (offerId) async {
        await OfferService.rejectOffer(_trip?.id, offerId);
      },
    ))).then((resultado) {
      _isNavigating = false;
      // Aceptada (con o sin socket): la celebración sale encima de ESTE
      // rastreo; si `offer:accepted` ya la mostró, no se repite.
      if (resultado is OfertaAceptadaResultado) {
        _mostrarOfertaAceptada(resultado.conductor);
      }
    }, onError: (_) {
      _isNavigating = false;
    });
  }

  Future<void> _cancelarBusqueda() async {
    if (_cancelling) return;
    final motivo = await elegirMotivoCancelacionBusqueda(context);
    if (motivo != null) _doCancel(motivo: motivo);
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
      titulo: _getAppBarTitle(),
      acciones: _accionesBusqueda(),
    );
  }

  Widget _buildPulseAnimation() => const _PulseSearchIndicator();

  /// Con el conductor yendo por la carga la ruta va del conductor al origen;
  /// desde que llega al origen, del origen al destino.
  bool get _faseRecogida => _status == TripStatus.aceptado || _status == TripStatus.enCamino;

  /// Pide la geometría de la ruta sólo cuando cambia la fase o sus extremos,
  /// o si el conductor se desvió mucho de la ruta de recogida; nunca en cada
  /// posición del GPS.
  void _asegurarRuta({required LatLng? conductor, required LatLng? origen, required LatLng? destino}) {
    final desde = _faseRecogida ? conductor : origen;
    final hasta = _faseRecogida ? origen : destino;
    if (desde == null || hasta == null) return;
    final fase = _faseRecogida ? 'recogida' : 'destino';
    final clave = _faseRecogida
        ? '$fase|${hasta.latitude},${hasta.longitude}'
        : '$fase|${desde.latitude},${desde.longitude}|${hasta.latitude},${hasta.longitude}';
    if (clave == _rutaClave) {
      if (!_faseRecogida || conductor == null || !_desviadoDeRuta(conductor)) return;
      // Desvío: como mucho una nueva consulta cada 30 s.
      final pedida = _rutaPedidaEn;
      if (pedida != null && DateTime.now().difference(pedida) < const Duration(seconds: 30)) return;
    }
    _rutaClave = clave;
    _rutaPedidaEn = DateTime.now();
    RouteService.getRoute(desde, hasta).then((puntos) {
      if (!mounted || _rutaClave != clave) return;
      setState(() {
        _ruta = puntos;
        _rutaDeClave = clave;
      });
    }).catchError((_) {});
  }

  /// Más de 500 m del punto más cercano de la ruta real.
  bool _desviadoDeRuta(LatLng conductor) {
    final ruta = _ruta;
    if (ruta == null || ruta.length <= 2) return false;
    var minimo = double.infinity;
    for (final p in ruta) {
      final d = _haversine(conductor.latitude, conductor.longitude, p.latitude, p.longitude);
      if (d < minimo) minimo = d;
    }
    return minimo > 500;
  }

  String _formatKm(num km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  /// Distancia total del viaje: la del backend si viene; si no, la recta
  /// entre origen y destino, dicha como aproximada.
  String? _distanciaViaje() {
    final d = _trip?.distancia;
    if (d != null && d > 0) return _formatKm(d);
    final o = _trip?.origen;
    final de = _trip?.destino;
    if (o == null || de == null) return null;
    if ((o.lat == 0 && o.lng == 0) || (de.lat == 0 && de.lng == 0)) return null;
    final km = _haversine(o.lat, o.lng, de.lat, de.lng) / 1000;
    return '≈ ${_formatKm(km)} en línea recta';
  }

  ({String estado, String? detalle, Color color}) _estadoSeguimiento() {
    switch (_status) {
      case TripStatus.aceptado:
        return (
          estado: 'Tu conductor va por tu carga',
          detalle: 'Te avisaremos cuando esté cerca del punto de recogida.',
          color: RastreoColores.primario,
        );
      case TripStatus.enCamino:
        return (
          estado: 'Tu conductor va hacia el punto de recogida',
          detalle: 'Ten la carga lista para entregarla.',
          color: RastreoColores.primario,
        );
      case TripStatus.llegada:
        return (
          estado: 'Tu conductor está en el punto de recogida',
          detalle: 'Entrégale la carga para comenzar el viaje.',
          color: RastreoColores.verde,
        );
      case TripStatus.enCurso:
        return (
          estado: 'Tu carga va hacia el destino',
          detalle: 'Sigue el camión en el mapa en tiempo real.',
          color: RastreoColores.verde,
        );
      case TripStatus.sos:
        return (
          estado: 'Alerta SOS activa',
          detalle: 'El equipo de soporte fue notificado y está atento a tu viaje.',
          color: RastreoColores.rojo,
        );
      default:
        return (estado: 'Seguimiento del viaje', detalle: null, color: RastreoColores.primario);
    }
  }

  Widget _buildTrackingContent() {
    final conductor = _trip?.conductor;
    final telefono = conductor?.telefono;
    final origen = MapaViaje.punto(_trip?.origen?.lat, _trip?.origen?.lng);
    final destino = MapaViaje.punto(_trip?.destino?.lat, _trip?.destino?.lng);
    final vehiculo = MapaViaje.punto(_driverLat, _driverLng);

    _asegurarRuta(conductor: vehiculo, origen: origen, destino: destino);

    // Ruta real si ya llegó la de esta fase; si no (o si el servicio de rutas
    // falló y devolvió los extremos), línea recta punteada.
    final desde = _faseRecogida ? vehiculo : origen;
    final hasta = _faseRecogida ? origen : destino;
    final rutaReal = _ruta != null && _ruta!.length > 2 && _rutaDeClave == _rutaClave;
    final List<LatLng>? ruta = rutaReal
        ? _ruta
        : (desde != null && hasta != null ? [desde, hasta] : null);

    final encuadre = <LatLng>[
      if (vehiculo != null) vehiculo else if (desde != null) desde,
      if (hasta != null) hasta,
    ];

    final double distanciaKm;
    final String distanciaEtiqueta;
    if (_faseRecogida || _status == TripStatus.llegada) {
      distanciaKm = _distanceToPickup();
      distanciaEtiqueta = 'Del conductor al punto de recogida';
    } else {
      distanciaKm = (vehiculo == null || destino == null)
          ? double.infinity
          : _haversine(vehiculo.latitude, vehiculo.longitude, destino.latitude, destino.longitude) / 1000;
      distanciaEtiqueta = 'Del camión al destino';
    }
    final eta = etaRecogida(
      status: _status,
      distanciaKm: _distanceToPickup(),
      tiempoEstimado: _trip?.tiempoEstimado,
      minutosServidor: _etaServidorMin,
    );
    final estado = _estadoSeguimiento();
    final media = MediaQuery.of(context);

    return SeguimientoViajeView(
      titulo: _getAppBarTitle(),
      mapa: MapaViaje(
        key: const ValueKey('mapa_seguimiento'),
        origen: origen,
        destino: destino,
        vehiculo: vehiculo,
        dibujarVehiculo: true,
        tipoVehiculo: conductor?.tipoVehiculo,
        rumboVehiculo: _driverRumbo,
        etiquetaVehiculo: etiquetaVehiculoAsignado(_status),
        ruta: ruta,
        rutaAproximada: !rutaReal,
        encuadre: encuadre,
        seguir: _seguirCamara,
        padding: EdgeInsets.fromLTRB(
          40,
          media.padding.top + 88,
          40,
          media.size.height * SeguimientoViajeView.tamanoInicialHoja + 24,
        ),
        onGestoUsuario: () {
          if (_seguirCamara && mounted) setState(() => _seguirCamara = false);
        },
      ),
      onRecentrar: _seguirCamara ? null : () => setState(() => _seguirCamara = true),
      estado: estado.estado,
      estadoDetalle: estado.detalle,
      colorEstado: estado.color,
      eta: eta,
      etaEtiqueta: 'Llegada estimada al punto de recogida',
      distancia: _formatDistance(distanciaKm),
      distanciaEtiqueta: distanciaEtiqueta,
      trip: _trip,
      calificacion: etiquetaCalificacionConductor(conductor?.toJson()),
      distanciaViaje: _distanciaViaje(),
      onChat: TripStatus.chatHabilitado(_status)
          ? () => _safePush(ChatScreen(trip: _trip?.toJson() ?? {}))
          : null,
      onLlamar: () async {
        if (telefono != null) {
          final uri = Uri.parse('tel:$telefono');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      onReportar: () {
        _safePush(ReportarProblemaScreen(
          trip: _trip?.toJson(),
          role: 'cliente',
          onSubmitted: () {
            _safePop();
          },
        ));
      },
      onSos: _sosSending ? null : _sendSos,
      sosEnviando: _sosSending,
      onCancelar: _cancelling ? null : _cancelar,
      textoCancelar: cancelacionRequiereSolicitud(_status) ? 'Solicitar cancelación' : 'Cancelar viaje',
    );
  }

  Future<void> _sendSos() async {
    if (_sosSending) return;
    // Devuelve el texto opcional (puede ser '') o null si se cancela.
    final descripcion = await showDialog<String>(
      context: context,
      builder: (_) => const _SosDialog(),
    );
    if (descripcion == null || !mounted) return;
    final motivo = descripcion.trim().isEmpty ? 'SOS enviado por el cliente' : descripcion.trim();

    setState(() => _sosSending = true);
    try {
      final alerta = await SosService.sendAlert(tripId: _trip?.id, motivo: motivo);
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

/// Confirmación del SOS con un texto opcional ("¿qué está pasando?"). El
/// backend avisa a administradores, moderadores de la zona y al otro
/// participante del viaje; NO al contacto de emergencia.
class _SosDialog extends StatefulWidget {
  const _SosDialog();

  @override
  State<_SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<_SosDialog> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar alerta SOS'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Se notificará al equipo de soporte y al conductor, con tu ubicación si está disponible.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _texto,
            maxLines: 2,
            // alertas_emergencia.motivo es varchar(100).
            inputFormatters: [LengthLimitingTextInputFormatter(SosService.motivoMax)],
            decoration: const InputDecoration(
              hintText: '¿Qué está pasando? (opcional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _texto.text),
          child: const Text('Enviar SOS'),
        ),
      ],
    );
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

/// Minutos de un `trip:eta_update` (`{minutos}`), o null si no es válido.
@visibleForTesting
int? minutosEta(Map<String, dynamic> data) {
  final v = data['minutos'];
  final n = v is num ? v : num.tryParse(v?.toString() ?? '');
  if (n == null || !n.isFinite || n < 0) return null;
  return n.ceil();
}

/// Pastilla bajo el vehículo del conductor asignado según la fase del viaje.
String? etiquetaVehiculoAsignado(String status) {
  switch (status) {
    case TripStatus.aceptado:
    case TripStatus.enCamino:
      return 'En camino';
    case TripStatus.llegada:
      return 'En el origen';
    case TripStatus.enCurso:
      return 'Con tu carga';
    default:
      return null;
  }
}

/// Vehículos de `/api/trips/:id/nearby-drivers` ({lat, lng, tipoVehiculo,
/// distanciaKm}) para el mapa de búsqueda. El backend no manda id ni rumbo;
/// si algún día llegan (`id`/`conductorId`, `heading`...), se usan.
List<VehiculoEnMapa> vehiculosCercanosEnMapa(List<Map<String, dynamic>> cercanos) {
  return [
    for (final c in cercanos)
      if (c['lat'] is num && c['lng'] is num)
        VehiculoEnMapa(
          id: (c['conductorId'] ?? c['id'])?.toString(),
          punto: LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble()),
          tipo: tipoVehiculoMapaDe(c['tipoVehiculo']?.toString()),
          color: colorVehiculoCercano,
          rumbo: rumboDePayload(c),
          tamano: 40,
        ),
  ];
}

/// Tiempo estimado de llegada del conductor al origen, o null si no hay
/// datos reales (no se muestra). Prioridad: la ETA en vivo del backend
/// (`trip:eta_update`), la posición en vivo a 30 km/h (misma velocidad que
/// el backend) y por último `tiempoEstimado` del viaje.
@visibleForTesting
String? etaRecogida({required String status, double? distanciaKm, num? tiempoEstimado, int? minutosServidor}) {
  if (status != TripStatus.aceptado && status != TripStatus.enCamino) return null;
  int? minutos;
  if (minutosServidor != null) {
    minutos = max(1, minutosServidor);
  } else if (distanciaKm != null && distanciaKm.isFinite) {
    minutos = max(1, (distanciaKm / 30 * 60).ceil());
  } else if (tiempoEstimado != null && tiempoEstimado > 0) {
    minutos = tiempoEstimado.ceil();
  }
  return minutos == null ? null : '$minutos min';
}

/// Tiempo que la celebración "¡Oferta aceptada!" queda sobre el rastreo
/// antes de cerrarse sola.
const Duration duracionCelebracionOferta = Duration(seconds: 4);

/// Suma a [actuales] las ofertas de [nuevas] que aún no están (por `_id`/`id`).
/// Las ofertas llegan por socket (`new:offer`) y por GET al abrir la pantalla.
@visibleForTesting
List<Map<String, dynamic>> fusionarOfertas(
    List<Map<String, dynamic>> actuales, List<Map<String, dynamic>> nuevas) {
  String? idDe(Map<String, dynamic> o) => (o['_id'] ?? o['id'])?.toString();
  final ids = actuales.map(idDe).whereType<String>().toSet();
  final r = List<Map<String, dynamic>>.from(actuales);
  for (final o in nuevas) {
    final id = idDe(o);
    if (id != null && !ids.add(id)) continue;
    r.add(Map<String, dynamic>.from(o));
  }
  return r;
}

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
/// para salir de la pantalla: una acción primaria (contactar a soporte, o
/// [accionPrimariaTexto] si se da otra) y volver al inicio.
class RastreoEstadoInfo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String mensaje;
  final VoidCallback? onSoporte;
  final VoidCallback onInicio;
  final String? textoCancelar;
  final VoidCallback? onCancelar;
  // Reemplaza el botón "Contactar a soporte" por una acción primaria propia
  // (p. ej. "Intentar de nuevo" cuando el sistema canceló por falta de
  // conductor). Si se da, [onSoporte] se ignora.
  final String? accionPrimariaTexto;
  final IconData? accionPrimariaIcon;
  final VoidCallback? onAccionPrimaria;

  const RastreoEstadoInfo({
    super.key,
    required this.icon,
    required this.color,
    required this.titulo,
    required this.mensaje,
    required this.onInicio,
    this.onSoporte,
    this.textoCancelar,
    this.onCancelar,
    this.accionPrimariaTexto,
    this.accionPrimariaIcon,
    this.onAccionPrimaria,
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
            if (onAccionPrimaria != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('btn_accion_primaria_rastreo_estado'),
                  onPressed: onAccionPrimaria,
                  icon: Icon(accionPrimariaIcon ?? Icons.refresh_rounded),
                  label: Text(accionPrimariaTexto ?? 'Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (onSoporte != null) ...[
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
            if (textoCancelar != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onCancelar,
                  icon: const Icon(Icons.event_busy),
                  label: Text(textoCancelar!),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
