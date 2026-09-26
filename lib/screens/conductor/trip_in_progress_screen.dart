import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../../contracts/cancelacion.dart';
import '../../contracts/cierre.dart';
import '../../contracts/socket_events.dart';
import '../../contracts/trip_status.dart';
import '../../models/location_model.dart';
import '../../models/trip.dart';
import '../../services/api_client.dart';
import '../../services/api/http_client.dart';
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
import '../../services/ruta_viaje_service.dart';
import '../../services/config_cliente_service.dart';
import '../../widgets/capa_vehiculos.dart';
import '../../widgets/mapa_viaje.dart';
import '../../widgets/persona_mapa.dart';
import '../../widgets/vehiculo_mapa.dart';
import 'esperando_confirmacion_cliente.dart';
import 'trip_chat_screen.dart';
import 'entrega_confirmada_screen.dart';
import 'resumen_viaje_screen.dart';
import 'calificar_cliente_screen.dart';
import 'sos_alert_screen.dart';
import '../shared/action_key.dart';
import '../shared/ui_compartida.dart' show BarraInferiorFija;
import '../shared/dispute_screen.dart';
import 'disputa_iniciada_wrapper.dart';

class TripInProgressScreen extends StatefulWidget {
  final Trip? trip;
  const TripInProgressScreen({super.key, this.trip});

  @override
  State<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends State<TripInProgressScreen> with WidgetsBindingObserver {
  Trip? _trip;
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
  // Rumbo del GPS (grados) sólo cuando el vehículo se mueve; si no, el
  // dibujo se orienta por el desplazamiento.
  double? _currentHeading;
  // El cronómetro vive en un ValueNotifier: sólo el texto del tiempo se
  // reconstruye cada segundo (antes setState() reconstruía toda la pantalla,
  // FlutterMap incluido, 1 vez por segundo).
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);
  int get _elapsedSeconds => _elapsed.value;
  set _elapsedSeconds(int v) => _elapsed.value = v;
  // Throttle de reconstrucciones por GPS (máx. 1 por segundo).
  DateTime _lastGpsRebuild = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _gpsRebuildTimer;
  bool _gpsStarting = false;
  bool _closeNavigated = false;
  String? _photoError;
  // Idempotencia: una clave por acción de cierre (reutilizada en reintentos).
  final ActionKey _completeKey = ActionKey();
  final ActionKey _finalizeKey = ActionKey();
  // Código del último error de POST /complete (p. ej. JUSTIFICACION_REQUERIDA).
  String? _ultimoErrorCierre;
  // Opciones del mapa y capa de tiles creadas una sola vez (no en cada build).
  MapOptions? _mapOptions;
  late final TileLayer _tileLayer = TileLayer(
    urlTemplate: MapConfig.tileUrl,
    userAgentPackageName: 'com.cargaexpress.app',
    maxZoom: 22,
  );
  List<Polyline> _routePolylines = const [];
  // Ruta al objetivo del estado (ver _actualizarRuta).
  String? _rutaClave;
  LatLng? _rutaDesde;
  DateTime _ultimaRuta = DateTime.fromMillisecondsSinceEpoch(0);
  bool _cargandoRuta = false;
  // Estado con el que se dibujó el mapa por última vez (encuadre/ruta al cambiar).
  String? _estadoDibujado;
  // La cámara sigue al conductor hasta que él mueve el mapa.
  bool _seguir = false;
  // Mientras el conductor no mueva el mapa, la cámara se reencuadra sola con
  // el conductor y su objetivo (el cliente antes de recoger, el destino
  // después) para que siempre vea hacia dónde va.
  bool _autoEncuadre = true;
  DateTime _ultimoAutoEncuadre = DateTime.fromMillisecondsSinceEpoch(0);
  // Alto del área del mapa y del panel (para encuadrar en la parte visible).
  double _mapAlto = 600;
  final GlobalKey _panelKey = GlobalKey();
  bool _rutaPendiente = false;

  double get _panelAlto {
    final box = _panelKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size.height;
    return _mapAlto * 0.5;
  }
  String? _deliveryPhotoUrl;
  Timer? _elapsedTimer;
  StreamSubscription<Map<String, dynamic>>? _finalizeResponseSub;
  StreamSubscription<Map<String, dynamic>>? _driverStopGpsSub;
  StreamSubscription<Map<String, dynamic>>? _closeRejectedSub;
  StreamSubscription<bool>? _lifecycleSub;
  final MapController _mapController = MapController();
  Timer? _tripStateTimer;
  bool _isCancelling = false;
  bool _isFinalizing = false;
  List<LatLng> _routePoints = [];
  bool _locationWarningShown = false;
  int _locationFailCount = 0;
  DateTime? _lastLocationSent;

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
    WidgetsBinding.instance.addObserver(this);
    AppLifecycleService.instance.init();

    _gpsSubscription = NotificationService.instance.onNotification.listen(_onSocketEvent);
    _finalizeResponseSub = SocketServiceClient.instance.onFinalizeResponse.listen(_onFinalizeResponse);
    _closeRejectedSub = SocketServiceClient.instance.onCloseRejected.listen(_onCloseRejected);
    _driverStopGpsSub = SocketServiceClient.instance.onDriverStopGps.listen((_) {
      _stopGpsTimer();
    });
    _escucharRutaServidor();

    final cachedTrip = CacheService.instance.getCachedActiveTrip();
    if (cachedTrip != null) {
      _trip = Trip.fromJson(cachedTrip);
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
      // El viaje salió de la caché local: se confirma de inmediato con el
      // backend (podía estar ya en disputa, cancelado o finalizado).
      WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizarConServidor());
    } else {
      _fetchActiveTrip();
    }

    _actualizarRuta(forzar: true);
    // Radio de cierre y plazo de confirmación del cliente (con valores por
    // defecto si el endpoint no responde). Al llegar se refrescan los avisos
    // de distancia del panel.
    ConfigClienteService.instance.cargar().then((_) {
      if (mounted) setState(() {});
    });

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
    _closeRejectedSub?.cancel();
    _driverStopGpsSub?.cancel();
    _etaSub?.cancel();
    _rutaSub?.cancel();
    _tripStateTimer?.cancel();
    _gpsRebuildTimer?.cancel();
    _cancelCountdown();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      LoggerService.instance.info('TripInProgress: app backgrounded, caching trip state');
      _cacheTripState();
      BackgroundLocationService.instance.updateNotification(
        estado: _trip?.estado,
        destino: _getDestinoDireccion(),
      );
    }
  }

  String? _getDestinoDireccion() {
    return _trip?.destino?.direccion;
  }

  void _cacheTripState() {
    if (_trip != null) {
      CacheService.instance.cacheActiveTrip(_trip!.toJson());
    }
  }

  Future<void> _restoreAfterBackground() async {
    if (_trip?.id != null) {
      await _sincronizarConServidor();
      _restartTimersIfNeeded();
      return;
    }
    try {
      final data = await ApiClient.instance.getActiveTrip();
      if (data != null && mounted) {
        final fresh = Trip.fromJson(data);
        setState(() {
          _trip = fresh;
          _elapsedSeconds = _calcularElapsed(fresh);
        });
        _cacheTripState();
        _restartTimersIfNeeded();
        return;
      }
    } catch (e) {
      LoggerService.instance.error('TripInProgress: error restoring after background', e);
      final cached = CacheService.instance.getCachedActiveTrip();
      if (cached != null && mounted) {
        setState(() { _trip = Trip.fromJson(cached); });
        _snack('Reconectado con el viaje en curso.');
        return;
      }
    }
    if (mounted) _salirDelViaje();
  }

  bool _saliendo = false;

  /// Sale de la pantalla del viaje UNA sola vez, de vuelta al inicio.
  /// Al cancelar llegan dos órdenes de salir casi a la vez: la respuesta del
  /// POST /cancel y el socket `trip:cancelled`, que entra durante la animación
  /// de salida con este State todavía montado. El segundo `Navigator.pop`
  /// quitaba el inicio del conductor y dejaba la app en negro (viaje 28).
  /// Si no hay ruta debajo, se limpia el viaje y se muestra "No hay viaje activo".
  void _salirDelViaje() {
    if (!mounted || _saliendo) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      _saliendo = true;
      nav.popUntil((r) => r.isFirst);
    } else {
      CacheService.instance.clearActiveTrip();
      setState(() => _trip = null);
    }
  }

  /// Segundos desde el inicio real (`enCursoAt` del backend). Antes leía un
  /// campo `inicio` que no existe y contaba desde que se abrió la pantalla.
  int _calcularElapsed(Trip trip) {
    final inicio = DateTime.tryParse(trip.enCursoAt ?? '');
    if (inicio == null) return _elapsedSeconds;
    final s = DateTime.now().difference(inicio).inSeconds;
    return s < 0 ? 0 : s;
  }

  void _restartTimersIfNeeded() {
    if (_locationTimer == null || !_locationTimer!.isActive) {
      _startGpsTimer();
    }
  }

  Timer? _countdownTimer;
  // Diálogo "Esperando confirmación" (30 s) en pantalla.
  bool _dialogoEsperaAbierto = false;

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _initLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
        });
        // Primera posición: ruta desde el conductor y encuadre con él.
        _actualizarRuta(forzar: true);
        _fitMapBounds();
      }
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
      // Sin `timeLimit`: geolocator CIERRA el flujo tras ese tiempo sin
      // posiciones nuevas y, con distanceFilter de 5 m, un vehículo parado
      // 30 s dejaba la pantalla sin GPS el resto del viaje (distancia
      // congelada, botones bloqueados y ubicación vieja en el backend).
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (Position pos) {
          try {
            if (!mounted) return;
            _posErrors = 0;
            if (pos.latitude == _currentLat && pos.longitude == _currentLng && pos.speed == _currentSpeed) return;
            CacheService.instance.cacheDriverPosition(pos.latitude, pos.longitude);
            // Los campos se actualizan siempre (_sendLocation los lee), pero la
            // UI se reconstruye como mucho 1 vez por segundo.
            _currentLat = pos.latitude;
            _currentLng = pos.longitude;
            _currentSpeed = pos.speed;
            _currentHeading = (pos.speed > 1.5 && pos.heading.isFinite && pos.heading > 0) ? pos.heading : null;
            _scheduleGpsRebuild();
            _emitirUbicacionAlCliente();
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
        onDone: () {
          // Si el plugin cierra el flujo, se reabre: el GPS no puede
          // quedarse mudo durante el viaje.
          if (!mounted) return;
          _posRetryTimer?.cancel();
          _posRetryTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) _startPositionStream();
          });
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

  void _scheduleGpsRebuild() {
    if (!mounted) return;
    final since = DateTime.now().difference(_lastGpsRebuild);
    const minGap = Duration(seconds: 1);
    if (since >= minGap) {
      _lastGpsRebuild = DateTime.now();
      _onGpsRebuild();
      return;
    }
    _gpsRebuildTimer ??= Timer(minGap - since, () {
      _gpsRebuildTimer = null;
      if (!mounted) return;
      _lastGpsRebuild = DateTime.now();
      _onGpsRebuild();
    });
  }

  Trip _tripWith(Trip t, {String? estado, num? precioFinal}) {
    final json = t.toJson();
    if (estado != null) json['estado'] = estado;
    if (precioFinal != null) json['precioFinal'] = precioFinal;
    return Trip.fromJson(json);
  }

  static const _estadosSeguidos = {
    TripStatus.aceptado,
    TripStatus.enCamino,
    TripStatus.llegada,
    TripStatus.enCurso,
    TripStatus.entregado,
    TripStatus.esperaConfirmacion,
    TripStatus.pendienteConfirmacion,
    // Emergencia: el viaje sigue activo hasta que soporte la resuelva.
    TripStatus.sos,
  };

  /// `trip:status_changed` del backend: fuente de verdad del estado del viaje.
  void _onTripStatusChanged(Map<String, dynamic> event) {
    final t = _trip;
    final estado = event['estado'] as String?;
    if (!mounted || t == null || estado == null) return;
    final id = (event['id'] ?? event['viajeId'] ?? event['tripId'])?.toString();
    if (id != null && id != t.id.toString()) return;
    if (estado == t.estado) return;
    if (estado == TripStatus.finalizado) {
      // El cliente confirmó el cierre (o se cerró por timeout del backend).
      _trip = _tripWith(t, estado: estado, precioFinal: event['montoFinal'] as num?);
      _goToEntregaConfirmada(_trip!);
    } else if (_estadosSeguidos.contains(estado)) {
      setState(() => _trip = _tripWith(t, estado: estado));
      _cacheTripState();
    }
  }

  void _onSocketEvent(Map<String, dynamic> event) {
    try {
      final tipo = event['__event'] as String?;
      if (tipo == 'driver:stop_gps') {
        _stopGpsTimer();
      } else if (tipo == SocketEvents.tripStatusChanged) {
        _onTripStatusChanged(event);
      } else if (tipo == 'trip:cancelled') {
        if (mounted) {
          // Si canceló el propio conductor, _cancelTrip ya lo confirmó.
          final msg = mensajeViajeCancelado(event, miRol: ApiClient.instance.rol);
          if (msg != null) _snack(msg);
          _stopGpsTimer();
          WidgetsBinding.instance.addPostFrameCallback((_) => _salirDelViaje());
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
          // Sólo se cierra el diálogo de espera si sigue abierto: si ya se
          // cerró (tiempo agotado o cancelado), este `pop` sacaría la
          // pantalla del viaje.
          if (_dialogoEsperaAbierto) Navigator.pop(context);
          if (accepted) {
            _finalizeTrip();
          } else {
            final motivo = data['motivo'] as String? ?? 'Cliente rechaz\u00f3 confirmaci\u00f3n de entrega';
            _snack('El cliente rechaz\u00f3 la confirmaci\u00f3n. Se abrir\u00e1 una disputa.');
            try {
              final disputeResult = await ApiClient.instance.disputeTrip(
                _trip?.id,
                motivo: 'Rechazo de entrega',
                descripcion: motivo,
              );
              final disputeId = disputeResult['id'] ?? disputeResult['disputeId'];
              if (mounted) {
                final trip = _trip;
                final origenText = trip?.origen?.direccion ?? '';
                final destinoText = trip?.destino?.direccion ?? '';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DisputaIniciadaWrapper(
                      tripId: trip?.id,
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

  void _onCloseRejected(Map<String, dynamic> data) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      // El backend ya cre\u00f3 la disputa (trip:close_rejected trae disputaId y
      // motivo): se muestra al conductor en vez de dejar el viaje congelado.
      _abrirDisputa(
        disputeId: data['disputaId'],
        motivo: data['motivo']?.toString() ?? 'El cliente rechaz\u00f3 el cierre del servicio',
      );
    });
  }

  bool _disputaMostrada = false;

  void _abrirDisputa({dynamic disputeId, required String motivo}) {
    if (!mounted || _disputaMostrada) return;
    _disputaMostrada = true;
    _cancelCountdown();
    final trip = _trip;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DisputaIniciadaWrapper(
        tripId: trip?.id,
        disputeId: disputeId,
        motivo: motivo,
        origen: trip?.origen?.direccion ?? '',
        destino: trip?.destino?.direccion ?? '',
      ),
    ));
  }

  /// Estado real del viaje seg\u00fan el backend (GET /api/trips/:id). Se usa al
  /// volver del segundo plano y cada 20 s: si el viaje cambi\u00f3 por acciones de
  /// otros (el cliente rechaz\u00f3 el cierre, se cancel\u00f3, se finaliz\u00f3), la
  /// pantalla lo refleja en vez de quedarse con datos viejos.
  Future<void> _sincronizarConServidor() async {
    final id = _trip?.id;
    if (id == null || !mounted) return;
    Map<String, dynamic> data;
    try {
      data = await ApiClient.instance.getTripDetail(id);
    } catch (_) {
      return; // sin red: se reintenta en el siguiente ciclo
    }
    if (!mounted) return;
    final fresh = Trip.fromJson(data);
    final nuevo = fresh.estado;
    if (nuevo == null || nuevo == _trip?.estado) return;
    switch (nuevo) {
      case TripStatus.disputa:
        _abrirDisputa(disputeId: data['disputaId'], motivo: 'El cliente rechaz\u00f3 el cierre del servicio');
        return;
      case TripStatus.finalizado:
        _trip = fresh;
        _goToEntregaConfirmada(fresh);
        return;
      case TripStatus.cancelado:
        _snack('El viaje fue cancelado.');
        _salirDelViaje();
        return;
      default:
        setState(() => _trip = fresh);
    }
  }

  /// Devuelve la ruta subida, o null si el usuario canceló o falló la subida
  /// (en ese caso deja el motivo en [_photoError] y lo muestra).
  Future<String?> _takeDeliveryPhoto() async {
    _photoError = null;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final url = await TripService.deliveryPhoto(_trip!.id, bytes, 'delivery_${DateTime.now().millisecondsSinceEpoch}.jpg');
      return url;
    } on ApiException catch (e) {
      LoggerService.instance.error('Error uploading delivery photo', e);
      _photoError = e.message;
    } catch (e) {
      LoggerService.instance.error('Error taking delivery photo', e);
      _photoError = 'No se pudo subir la foto: ${e.toString().replaceFirst("Exception: ", "")}';
    }
    if (mounted && _photoError != null) _snack(_photoError!);
    return null;
  }

  // El backend exige llegar a 'esperando_confirmacion' ANTES de finalizar:
  // en_curso -> entregado -> esperando_confirmacion -> finalizado.
  // POST /api/trips/:id/complete {montoFinal, justificacion?} hace en_curso/entregado ->
  // esperando_confirmacion automáticamente. Devuelve false si no se pudo
  // completar (se aborta la solicitud de finalización).
  Future<bool> _completeTripIfNeeded(num? montoFinalOverride, {String? justificacion}) async {
    _ultimoErrorCierre = null;
    final t = _trip;
    if (t == null) return true;
    if (t.estado != TripStatus.enCurso && t.estado != TripStatus.entregado) return true;
    final montoFinal = montoFinalOverride ?? t.precioFinal ?? t.precioEstimado;
    if (montoFinal == null) {
      // El backend exige montoFinal (422 sin él).
      if (mounted) _snack('Debes indicar el monto final del viaje para cerrarlo.');
      return false;
    }
    try {
      final key = _completeKey.keyFor('${t.id}|$montoFinal|$justificacion');
      await DriverLocationService.instance.conUbicacionFresca(() => ApiClient.instance.completeTrip(t.id, montoFinal: montoFinal, justificacion: justificacion, idempotencyKey: key));
      _completeKey.settle();
      // El backend deja el viaje en 'pendiente_confirmacion' hasta que el
      // cliente confirme (no está finalizado todavía).
      _trip = _tripWith(t, estado: TripStatus.pendienteConfirmacion, precioFinal: montoFinal);
      _cacheTripState();
      return true;
    } on ApiException catch (e) {
      _completeKey.settle(e);
      _ultimoErrorCierre = e.code;
      LoggerService.instance.error('trip_in_progress: completeTrip error', e);
      if (e.code == 'JUSTIFICACION_REQUERIDA') {
        // El backend la exige (fuera del radio del destino): se pide la
        // justificaci\u00f3n en el di\u00e1logo; su mensaje ya trae la distancia.
        if (mounted) _snack(e.message);
      } else if (e.code == 'FUERA_DE_RANGO_ORIGEN') {
        if (mounted) _snack('Fuera de rango del origen. Distancia: ${e.message}');
      } else {
        if (mounted) _snack(e.message);
      }
      return false;
    } catch (e) {
      _completeKey.settle(e);
      LoggerService.instance.error('trip_in_progress: completeTrip error', e);
      if (mounted) _snack('Error al completar la entrega: ${e.toString().replaceFirst("Exception: ", "")}');
      return false;
    }
  }

  /// Precio acordado al aceptar la oferta: es el monto final y el conductor
  /// no lo cambia al cerrar (el backend lo ignora y usa el acordado).
  Future<num?> _promptMontoFinal() async {
    final t = _trip;
    if (t == null) return null;
    return t.precioFinal ?? t.precioEstimado ?? 0;
  }

  /// Toma el GPS actual antes de decidir si el cierre necesita justificación.
  /// Si falla se conserva la última posición conocida (o ninguna).
  Future<void> _actualizarUbicacionParaCierre() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
    } catch (e) {
      LoggerService.instance.error('trip_in_progress: ubicación para el cierre', e);
    }
  }

  /// Pide la justificación del cierre (mínimo 10 caracteres); null si el
  /// conductor cancela.
  Future<String?> _pedirJustificacionCierre(double radioKm) {
    final radio = radioKm == radioKm.roundToDouble() ? radioKm.toStringAsFixed(0) : radioKm.toString();
    // Fuera del builder: si se declara dentro, cada setDialogState() la
    // reinicia a null y el botón "Continuar" nunca se habilita.
    String? localJustificacion;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            // Con el teclado abierto el contenido se desplaza en vez de
            // quedar tapado por los botones.
            scrollable: true,
            title: const Text('Justificación de cierre'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Estás a más de $radio km del destino (o no tenemos tu ubicación). '
                    'Para cerrar el viaje escribe el motivo (mínimo 10 caracteres).'),
                const SizedBox(height: 16),
                TextField(
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Motivo del cierre...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: (v) {
                    localJustificacion = v.trim();
                    setDialogState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: (localJustificacion != null && localJustificacion!.length >= 10)
                    ? () => Navigator.pop(ctx, localJustificacion)
                    : null,
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestFinalization() async {
    if (_trip == null || _actionLoading) return;
    setState(() => _actionLoading = true);

    // Si ya subi\u00f3 la foto desde el panel no se vuelve a preguntar.
    final confirm = _deliveryPhotoUrl != null
        ? false
        : await showDialog<bool>(
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
      if (_deliveryPhotoUrl == null && _photoError != null && mounted) {
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al subir la foto'),
            content: Text('$_photoError\n\n¿Quieres intentarlo de nuevo?'),
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

    // Paso obligatorio del backend: marcar entrega completada antes de
    // solicitar la confirmación/finalización al cliente.
    final montoFinal = await _promptMontoFinal();
    if (!mounted) return;
    if (montoFinal == null) {
      _snack('Debes indicar el monto final del viaje para cerrarlo.');
      setState(() => _actionLoading = false);
      return;
    }

    // Justificación de cierre (antifraude): el backend la exige sólo fuera
    // del radio de cierre del destino. Sin ubicación conocida se pide igual.
    final reglas = await ConfigClienteService.instance.cargar();
    await _actualizarUbicacionParaCierre();
    if (!mounted) return;
    final destino = _trip?.destino;
    var pedirJustificacion = cierreRequiereJustificacion(
      lat: _currentLat,
      lng: _currentLng,
      destinoLat: destino?.lat,
      destinoLng: destino?.lng,
      radioKm: reglas.radioCierreKm,
    );
    String? justificacion;
    while (true) {
      if (pedirJustificacion) {
        justificacion = await _pedirJustificacionCierre(reglas.radioCierreKm);
        if (!mounted) return;
        if (justificacion == null) {
          setState(() => _actionLoading = false);
          return;
        }
      }
      final completado = await _completeTripIfNeeded(montoFinal, justificacion: justificacion);
      if (!mounted) return;
      if (completado) break;
      // El backend es quien decide: si la exige, se muestra el campo.
      if (!pedirJustificacion && _ultimoErrorCierre == 'JUSTIFICACION_REQUERIDA') {
        pedirJustificacion = true;
        continue;
      }
      setState(() => _actionLoading = false);
      return;
    }

    SocketServiceClient.instance.emit('trip:finalize_request', {
      'tripId': _trip!.id,
      'trip': _trip!.toJson(),
      if (_deliveryPhotoUrl != null) 'foto': _deliveryPhotoUrl,
    });

    if (!mounted) return;
    setState(() => _actionLoading = true);

    // Antes: el Timer hacía setState() de TODA la pantalla cada segundo y el
    // texto del diálogo (otra ruta) ni siquiera se refrescaba. Ahora sólo el
    // contador del diálogo escucha este ValueNotifier.
    final countdown = ValueNotifier<int>(30);
    _cancelCountdown();
    _dialogoEsperaAbierto = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
          countdown.value--;
          if (countdown.value <= 0) {
            timer.cancel();
            _countdownTimer = null;
            if (ctx.mounted) Navigator.pop(ctx);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _snack('El cliente a\u00fan no responde. El viaje queda pendiente de su confirmaci\u00f3n.');
                _finalizeTrip();
              }
            });
          }
        });
        return AlertDialog(
              title: const Text('Esperando confirmaci\u00f3n'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Solicitando confirmaci\u00f3n al cliente...'),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<int>(
                    valueListenable: countdown,
                    builder: (_, timeoutSec, _) => Text('Tiempo restante: $timeoutSec s',
                      style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700,
                        color: timeoutSec < 10 ? Colors.red : _primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _cancelCountdown();
                    SocketServiceClient.instance.emit('trip:finalize_cancelled', {
                      'tripId': _trip?.id,
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
    _dialogoEsperaAbierto = false;
    _cancelCountdown();
    countdown.dispose();
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final data = await ApiClient.instance.getActiveTrip();
      final trip = data != null ? Trip.fromJson(data) : null;
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
    // Cronómetro y sincronización no dependen del GPS: antes se iniciaban
    // sólo con permiso de ubicación y sin él el viaje no se sincronizaba.
    _startTripTimers();
    // Evitar timers duplicados si se llama dos veces mientras se pide permiso.
    if (_locationTimer != null || _gpsStarting) return;
    _gpsStarting = true;
    final bool granted;
    try {
      granted = await _requestLocationPermission();
    } finally {
      _gpsStarting = false;
    }
    if (!granted || !mounted || _locationTimer != null) return;

    DriverLocationService.instance.pause(); // evitar triple GPS

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendLocation());
    _sendLocation();
  }

  void _startTripTimers() {
    if (_elapsedTimer == null) {
      // Con enCursoAt el cronómetro se recalcula desde el inicio real (sigue
      // bien tras reabrir la app o volver de segundo plano); sin él, cuenta.
      final t0 = _trip;
      if (t0?.enCursoAt != null) _elapsedSeconds = _calcularElapsed(t0!);
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final t = _trip;
        _elapsedSeconds = t?.enCursoAt != null ? _calcularElapsed(t!) : _elapsedSeconds + 1;
      });
    }
    // Con socket o sin él: los eventos se pierden si la app estuvo en segundo
    // plano o se reconectó; el estado del backend manda.
    _tripStateTimer ??= Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted) return;
      await _sincronizarConServidor();
    });
  }

  void _stopGpsTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
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

  DateTime? _lastSocketLocation;

  /// Posición al cliente por socket en cada lectura del GPS (máx. cada 2 s):
  /// antes sólo salía cada 10 s con _sendLocation y el camión del cliente iba
  /// atrasado respecto al mapa del conductor. El HTTP (persistencia y reglas
  /// antifraude del backend) sigue cada 10 s.
  void _emitirUbicacionAlCliente() {
    final t = _trip;
    final lat = _currentLat, lng = _currentLng;
    if (t == null || lat == null || lng == null || !_isTripActive) return;
    final ahora = DateTime.now();
    if (_lastSocketLocation != null && ahora.difference(_lastSocketLocation!).inMilliseconds < 2000) return;
    if (!SocketServiceClient.instance.isConnected) return;
    _lastSocketLocation = ahora;
    SocketServiceClient.instance.emit('driver:location', {
      'tripId': t.id,
      'latitude': lat,
      'longitude': lng,
      'speed': _currentSpeed ?? 0,
      if (_currentHeading != null) 'heading': _currentHeading,
    });
  }

  Future<void> _sendLocation() async {
    if (_lastLocationSent != null && DateTime.now().difference(_lastLocationSent!).inSeconds < 10) return;
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
        'tripId': _trip!.id,
        'latitude': _currentLat,
        'longitude': _currentLng,
        'speed': _currentSpeed ?? 0,
      });
    }

    // HTTP para persistencia backend
    try {
      await ApiClient.instance.updateLocation(_currentLat!, _currentLng!);
      _lastLocationSent = DateTime.now();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('429') || msg.contains('RateLimited')) return;
      LoggerService.instance.error('_sendLocation error', e);
    }
  }

  Future<void> _startTrip() async {
    if (_trip == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await DriverLocationService.instance.conUbicacionFresca(() => ApiClient.instance.startTrip(_trip!.id));
      final json = _trip!.toJson();
      json['estado'] = TripStatus.enCurso;
      // El cronómetro cuenta desde el inicio: sin esto seguía desde que se
      // abrió la pantalla (start-trip no devuelve el viaje; el backend fija
      // enCursoAt en este momento).
      json['enCursoAt'] ??= DateTime.now().toUtc().toIso8601String();
      _trip = Trip.fromJson(json);
      _elapsedSeconds = 0;
      if (mounted) setState(() {});
      _snack('Viaje iniciado');
      _startGpsTimer();
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _confirmArrival() async {
    if (_trip == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await DriverLocationService.instance.conUbicacionFresca(() => ApiClient.instance.confirmArrival(_trip!.id));
      final json = _trip!.toJson();
      json['estado'] = TripStatus.enCamino;
      _trip = Trip.fromJson(json);
      if (mounted) setState(() {});
      _snack('Conduciendo hacia el origen');
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _confirmPickup() async {
    if (_trip == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await DriverLocationService.instance.conUbicacionFresca(() => ApiClient.instance.confirmPickup(_trip!.id));
      final json = _trip!.toJson();
      json['estado'] = TripStatus.llegada;
      _trip = Trip.fromJson(json);
      if (mounted) setState(() {});
      _snack('Has llegado al origen');
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  /// Solicita el cierre al backend y sigue el estado REAL que éste devuelve.
  /// El backend deja el viaje en 'pendiente_confirmacion' hasta que el cliente
  /// confirme; sólo con 'finalizado' (respuesta o socket) se muestra el resumen.
  Future<void> _finalizeTrip() async {
    if (_trip == null || _isFinalizing) return;
    _isFinalizing = true;
    setState(() => _actionLoading = true);
    try {
      var t = _trip!;
      var estado = t.estado;
      if (estado == TripStatus.enCurso || estado == TripStatus.entregado) {
        num? montoFinal = t.precioFinal ?? t.precioEstimado;
        montoFinal ??= await _promptMontoFinal();
        if (!mounted) return;
        if (montoFinal == null) {
          _snack('Debes indicar el monto final del viaje para cerrarlo.');
          return;
        }
        final monto = montoFinal;
        final key = _finalizeKey.keyFor('${t.id}|$monto');
        try {
          await DriverLocationService.instance.conUbicacionFresca(() => ApiClient.instance.finalizeTrip(t.id, montoFinal: monto, idempotencyKey: key));
          _finalizeKey.settle();
        } catch (e) {
          _finalizeKey.settle(e);
          rethrow;
        }
        estado = TripStatus.pendienteConfirmacion;
        t = _tripWith(t, estado: estado, precioFinal: monto);
      }
      // Estado real según el backend (puede que el cliente ya haya confirmado).
      try {
        final fresh = await ApiClient.instance.getTripDetail(t.id);
        final e = fresh['estado'] as String?;
        if (e != null) estado = e;
      } catch (e) {
        // Nos quedamos con el último estado conocido; el socket lo corregirá.
        LoggerService.instance.error('trip_in_progress: getTripDetail tras cierre', e);
      }
      t = _tripWith(t, estado: estado);
      _trip = t;
      _cacheTripState();
      if (!mounted) return;
      if (estado == TripStatus.finalizado) {
        _goToEntregaConfirmada(t);
      } else {
        setState(() {});
        _snack('Esperando que el cliente confirme la entrega.');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
      _isFinalizing = false;
    }
  }

  void _goToEntregaConfirmada(Trip t) {
    if (_closeNavigated || !mounted) return;
    _closeNavigated = true;
    _stopGpsTimer();
    _cancelCountdown();
    CacheService.instance.clearActiveTrip();

    final precio = t.precioFinal ?? t.precioEstimado ?? 0;
    final pctComision = t.toJson()['porcentajeComision'] as num? ?? 10;
    String miles(num v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    final precioStr = '\$${miles(precio)}';
    final comisionVal = precio * (pctComision / 100);
    final comisionStr = '- \$${miles(comisionVal)}';
    final totalStr = '\$${miles(precio - comisionVal)}';
    final cliente = t.cliente;
    final nombreCliente = cliente?.nombre ?? '';
    final rating = cliente?.calificacion ?? 4.0;
    final origenText = t.origen?.direccion ?? '';
    final destinoText = t.destino?.direccion ?? '';
    final duracion = _formatElapsed();
    // Esta pantalla se elimina con pushAndRemoveUntil: los callbacks deben usar
    // el NavigatorState (vivo) y no el `context` de este State ya desmontado.
    final nav = Navigator.of(context);

    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => EntregaConfirmadaScreen(
          nombreCliente: nombreCliente,
          ratingCliente: rating,
          precioAcordado: precioStr,
          comision: comisionStr,
          porcentajeComision: '${pctComision.toInt()}%',
          gananciaTotal: totalStr,
          onVerResumen: () => _pushResumenViaje(
            nav, t, precioStr, comisionStr, '${pctComision.toInt()}%', totalStr, origenText, destinoText, duracion,
          ),
          onCalificarCliente: () => _pushCalificarCliente(nav, t.id, nombreCliente, rating),
          onVolverInicio: () => nav.popUntil((route) => route.isFirst),
        ),
      ),
      // Se conserva el inicio del conductor: al calificar, popUntil(isFirst)
      // vuelve a él (con `(route) => false` la pantalla de entrega quedaba
      // como raíz y el conductor volvía a ella en bucle).
      (route) => route.isFirst,
    );
  }

  void _pushResumenViaje(
    NavigatorState nav,
    Trip t,
    String precioStr, String comisionStr, String pctComision, String totalStr,
    String origenText, String destinoText, String duracion,
  ) {
    nav.push(
      MaterialPageRoute(
        builder: (_) => ResumenViajeScreen(
          data: ResumenViajeData(
            origen: origenText,
            destino: destinoText,
            distanciaTotal: t.distancia != null
                ? '${t.distancia} km'
                : '${_haversine(
              t.origen?.lat ?? 0,
              t.origen?.lng ?? 0,
              t.destino?.lat ?? 0,
              t.destino?.lng ?? 0,
            ).toStringAsFixed(1)} km (aprox.)',
            duracionTotal: duracion,
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

  void _pushCalificarCliente(NavigatorState nav, dynamic tripId, String nombreCliente, double rating) {
    nav.push(
      MaterialPageRoute(
        builder: (ctx) => CalificarClienteScreen(
          nombreCliente: nombreCliente,
          ratingActual: rating,
          onEnviar: (estrellas, comentario) async {
            final messenger = ScaffoldMessenger.maybeOf(ctx);
            try {
              await ApiClient.instance.rateTrip(tripId, estrellas, comentario: comentario);
            } on ApiException catch (e) {
              messenger?.showSnackBar(SnackBar(content: Text(e.message)));
            } catch (_) {
              messenger?.showSnackBar(const SnackBar(content: Text('No se pudo enviar la calificaci\u00f3n.')));
            }
            if (!nav.mounted) return;
            nav.popUntil((route) => route.isFirst);
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
    final e = _trip?.estado;
    return _estadosSeguidos.contains(e);
  }

  // ---------------------------------------------------------------------------
  // Distancias y reglas antifraude (el backend es quien decide; aquí sólo se
  // explica y se evita un intento que sabemos que va a fallar).
  // ---------------------------------------------------------------------------

  /// Radio (km) con el que el backend considera al conductor "en" el origen o
  /// el destino (`radioCierreKm` de GET /api/config/cliente; la recogida usa
  /// `radioRecogidaKm`, que por defecto vale lo mismo: 1 km).
  double get _radioKm => ConfigClienteService.instance.actual.radioCierreKm;

  /// Antes de recoger la carga el objetivo es el origen; después, el destino.
  static bool _antesDeRecoger(String? estado) =>
      estado == TripStatus.aceptado || estado == TripStatus.enCamino || estado == TripStatus.llegada;

  double? _distanciaA(LocationModel? p) {
    if (_currentLat == null || _currentLng == null || p == null) return null;
    if (p.lat == 0 && p.lng == 0) return null;
    return _haversine(_currentLat!, _currentLng!, p.lat, p.lng);
  }

  double? get _distOrigenKm => _distanciaA(_trip?.origen);
  double? get _distDestinoKm => _distanciaA(_trip?.destino);

  bool get _isNearDestination {
    final d = _distDestinoKm;
    return d != null && d < _radioKm;
  }

  /// Con GPS y a `radioKm` o más del origen el backend rechaza la llegada y
  /// el inicio (FUERA_DE_RANGO_ORIGEN) y lo registra como posible fraude: se
  /// bloquea el botón y se explica. Sin GPS se deja intentar (decide el backend).
  bool get _lejosDelOrigen {
    final d = _distOrigenKm;
    return d != null && d >= _radioKm;
  }

  static String _fmtDist(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  static String _fmtRadio(double km) =>
      km == km.roundToDouble() ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km';

  /// Precio con separador de miles: 17000 -> "$17.000".
  static String _fmtPrecio(num? v) {
    if (v == null) return '--';
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}\$$b';
  }

  // ETA y metros restantes del backend (trip:eta_update / GET route) para la
  // fase actual: la misma estimación que ve el cliente.
  int? _etaServidorMin;
  String? _etaFase;
  double? _restanteServidorM;
  StreamSubscription<Map<String, dynamic>>? _etaSub;
  StreamSubscription<Map<String, dynamic>>? _rutaSub;

  /// Fase de la ruta del backend (trip_route_service.faseDe): en el origen
  /// ('conductor_llegada') ya se muestra el camino al destino.
  String get _faseActual {
    final e = _trip?.estado;
    return (e == TripStatus.aceptado || e == TripStatus.enCamino) ? 'recogida' : 'destino';
  }

  void _aplicarEtaServidor(RutaViaje r) {
    if (r.minutos == null) return;
    _etaServidorMin = r.minutos;
    _etaFase = r.fase;
    _restanteServidorM = r.restanteM;
  }

  void _escucharRutaServidor() {
    _etaSub = SocketServiceClient.instance.onTripEtaUpdate.listen((data) {
      final r = RutaViaje.fromJson(data);
      if (r == null || !mounted) return;
      setState(() => _aplicarEtaServidor(r));
    });
    _rutaSub = SocketServiceClient.instance.onTripRouteUpdate.listen((data) {
      final r = RutaViaje.fromJson(data);
      final id = data['tripId']?.toString();
      if (r == null || !mounted || (id != null && id != _trip?.id.toString())) return;
      if (r.fase != _faseActual) return;
      final points = r.coords;
      setState(() {
        _aplicarEtaServidor(r);
        if (points != null && points.length >= 2) {
          _routePoints = points;
          _routePolylines = [
            Polyline(points: points, color: Colors.black.withValues(alpha: 0.2), strokeWidth: 8),
            Polyline(points: points, color: const Color(0xFF2563EB), strokeWidth: 5),
          ];
        }
      });
    });
  }

  /// Texto "~8 min": la del backend si es de esta fase; si no, estimación
  /// local a la velocidad actual (o 30 km/h si va despacio/parado).
  String _fmtEta(double km) {
    // En el origen ('conductor_llegada') el panel habla del origen pero la
    // ruta del backend ya es al destino: ahí no se mezclan.
    final mismoObjetivo = _antesDeRecoger(_trip?.estado) == (_faseActual == 'recogida');
    final servidor = (_etaFase == _faseActual && mismoObjetivo) ? _etaServidorMin : null;
    if (servidor != null) {
      if (servidor >= 60) return '~${servidor ~/ 60} h ${servidor % 60} min';
      return servidor < 1 ? 'menos de 1 min' : '~$servidor min';
    }
    final spd = (_currentSpeed ?? 0) * 3.6;
    final v = spd > 5 ? spd : 30.0;
    final min = (km / v * 60).round();
    if (min < 1) return 'menos de 1 min';
    if (min >= 60) return '~${min ~/ 60} h ${min % 60} min';
    return '~$min min';
  }

  // ---------------------------------------------------------------------------
  // Mapa: ruta al objetivo, encuadre y seguimiento del conductor.
  // ---------------------------------------------------------------------------

  /// Ruta por calles desde el conductor hasta el objetivo del estado (origen
  /// antes de recoger, destino después). Se vuelve a pedir al cambiar de
  /// estado, o si el conductor se alejó >250 m de donde se calculó y pasaron
  /// 45 s (para no saturar el servicio de rutas).
  Future<void> _actualizarRuta({bool forzar = false}) async {
    final t = _trip;
    if (t == null) return;
    final origen = t.origen;
    final destino = t.destino;
    if (origen == null || destino == null) return;
    final antes = _antesDeRecoger(t.estado);
    final pos = (_currentLat != null && _currentLng != null) ? LatLng(_currentLat!, _currentLng!) : null;
    // Sin GPS todavía se dibuja el recorrido origen -> destino.
    final desde = pos ?? LatLng(origen.lat, origen.lng);
    final objetivo = (antes && pos != null) ? LatLng(origen.lat, origen.lng) : LatLng(destino.lat, destino.lng);
    final clave = '${antes ? 'origen' : 'destino'}|${pos != null}';
    final anterior = _rutaDesde;
    if (!forzar && clave == _rutaClave && anterior != null) {
      final movido = _haversine(desde.latitude, desde.longitude, anterior.latitude, anterior.longitude);
      if (movido < 0.25 || DateTime.now().difference(_ultimaRuta) < const Duration(seconds: 45)) return;
    }
    if (_cargandoRuta) {
      // Se repite al terminar la petición en curso (p. ej. llegó el GPS).
      _rutaPendiente = true;
      return;
    }
    _cargandoRuta = true;
    _rutaClave = clave;
    _rutaDesde = desde;
    _ultimaRuta = DateTime.now();
    try {
      // Ruta del backend (la misma del cliente, cacheada allá: no cuesta una
      // llamada a Mapbox por pantalla). Sin ella, recta hasta el objetivo.
      final r = await RutaViaje.obtener(t.id);
      final points = (r != null && r.fase == _faseActual && r.coords != null && r.coords!.length >= 2)
          ? r.coords!
          : <LatLng>[desde, objetivo];
      if (r != null) _aplicarEtaServidor(r);
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routePolylines = points.length < 2
            ? const []
            : [
                Polyline(points: points, color: Colors.black.withValues(alpha: 0.2), strokeWidth: 8),
                Polyline(points: points, color: const Color(0xFF2563EB), strokeWidth: 5),
              ];
      });
    } catch (e) {
      LoggerService.instance.error('trip_in_progress: ruta', e);
    } finally {
      _cargandoRuta = false;
    }
    if (_rutaPendiente && mounted) {
      _rutaPendiente = false;
      _actualizarRuta(forzar: true);
    }
  }

  /// Encuadra al conductor y su objetivo (o el origen y el destino si aún no
  /// hay GPS) en la parte del mapa que no tapa el panel.
  void _fitMapBounds() {
    final t = _trip;
    if (t == null) return;
    final antes = _antesDeRecoger(t.estado);
    final objetivo = antes ? t.origen : t.destino;
    final points = <LatLng>[];
    if (_currentLat != null && _currentLng != null) points.add(LatLng(_currentLat!, _currentLng!));
    if (objetivo != null && !(objetivo.lat == 0 && objetivo.lng == 0)) points.add(LatLng(objetivo.lat, objetivo.lng));
    if (points.length < 2) {
      // Sin GPS todavía: se enfoca el objetivo (el cliente antes de recoger)
      // en vez de toda la ruta origen→destino.
      if (objetivo != null && !(objetivo.lat == 0 && objetivo.lng == 0)) {
        try {
          _mapController.move(LatLng(objetivo.lat, objetivo.lng), 16, offset: Offset(0, -_panelAlto / 2));
        } catch (_) {}
        return;
      }
      final origen = t.origen;
      final destino = t.destino;
      points.clear();
      if (origen != null) points.add(LatLng(origen.lat, origen.lng));
      if (destino != null) points.add(LatLng(destino.lat, destino.lng));
    }
    try {
      if (points.isEmpty) return;
      if (points.length == 1) {
        _mapController.move(points.first, 15);
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: EdgeInsets.fromLTRB(50, 70, 50, _panelAlto + 40),
          maxZoom: 17,
        ),
      );
    } catch (_) {
      // El mapa aún no está listo: onMapReady vuelve a encuadrar.
    }
  }

  void _centrarEnConductor() {
    if (_currentLat == null || _currentLng == null) return;
    try {
      final zoom = _mapController.camera.zoom;
      _mapController.move(
        LatLng(_currentLat!, _currentLng!),
        zoom < 15 ? 16 : zoom,
        // El panel tapa la parte inferior: el conductor se dibuja en el
        // centro de la parte visible.
        offset: Offset(0, -_panelAlto / 2),
      );
    } catch (_) {}
  }

  /// Reconstrucción por GPS (como mucho 1/s): panel, seguimiento y ruta.
  void _onGpsRebuild() {
    setState(() {});
    if (_seguir) {
      _centrarEnConductor();
    } else if (_autoEncuadre &&
        DateTime.now().difference(_ultimoAutoEncuadre) > const Duration(seconds: 6)) {
      _ultimoAutoEncuadre = DateTime.now();
      _fitMapBounds();
    }
    _actualizarRuta();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
    final estado = t.estado ?? '';
    if (estado != _estadoDibujado) {
      // Cambió el estado (acción propia, socket o sondeo): nuevo objetivo en
      // el mapa y nueva ruta.
      _estadoDibujado = estado;
      _autoEncuadre = true; // nuevo objetivo (cliente → destino): volver a enfocarlo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _actualizarRuta(forzar: true);
        _fitMapBounds();
      });
    }

    return PopScope(
      canPop: !_isTripActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          _snack('Acción no permitida hasta finalizar el viaje.');
        }
      },
      child: Scaffold(
        backgroundColor: _bgLight,
        body: Column(
          children: [
            _buildHeader(context, estado),
            Expanded(child: _buildMapWithContent(t, estado)),
            _buildBottomNav(t, estado),
          ],
        ),
      ),
    );
  }

  static String _etiquetaEstado(String estado) {
    switch (estado) {
      case TripStatus.aceptado: return 'Aceptado';
      case TripStatus.enCamino: return 'En camino';
      case TripStatus.llegada: return 'En el origen';
      case TripStatus.enCurso: return 'En curso';
      case TripStatus.entregado: return 'Entregado';
      case TripStatus.esperaConfirmacion:
      case TripStatus.pendienteConfirmacion: return 'Esperando confirmación';
      case TripStatus.finalizado: return 'Finalizado';
      default: return TripStatus.label(estado);
    }
  }

  Widget _buildHeader(BuildContext context, String estado) {
    return Container(
      color: _white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_isTripActive) {
                    _snack('Acción no permitida hasta finalizar el viaje.');
                  } else {
                    _salirDelViaje();
                  }
                },
                child: const Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Viaje en curso', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accentGreen.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _etiquetaEstado(estado),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _accentGreen, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Un solo mapa (ruta, origen, destino y conductor) con el panel del estado
  /// encima, en la parte inferior. El panel nunca ocupa más del 58 % del alto.
  Widget _buildMapWithContent(Trip t, String estado) {
    final origen = MapaViaje.punto(t.origen?.lat, t.origen?.lng);
    final destino = MapaViaje.punto(t.destino?.lat, t.destino?.lng);
    final centro = (_currentLat != null && _currentLng != null)
        ? LatLng(_currentLat!, _currentLng!)
        : (origen ?? destino ?? const LatLng(0, 0));

    // El cliente en el punto de recogida se dibuja como una persona con su
    // nombre; el destino, como un pin claro.
    final cajaPersona = PersonaMapa.caja(40, conEtiqueta: true);
    final markers = <Marker>[
      if (origen != null)
        Marker(
          point: origen,
          width: cajaPersona.width,
          height: cajaPersona.height,
          child: PersonaMapa(etiqueta: PersonaMapa.etiquetaDe(t.cliente?.nombre)),
        ),
      if (destino != null)
        Marker(point: destino, width: 40, height: 40, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 40, shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
    ];
    // El propio conductor: su vehículo visto desde arriba (según tipoVehiculo),
    // orientado al rumbo del GPS o, si no lo hay, al de su movimiento.
    final vehiculoConductor = (_currentLat != null && _currentLng != null)
        ? [
            VehiculoEnMapa(
              id: 'conductor',
              punto: LatLng(_currentLat!, _currentLng!),
              tipo: tipoVehiculoMapaDe(t.conductor?.tipoVehiculo),
              color: colorVehiculoAsignado,
              rumbo: _currentHeading,
              tamano: 48,
              halo: true,
            ),
          ]
        : const <VehiculoEnMapa>[];

    return LayoutBuilder(
      builder: (context, c) {
        _mapAlto = c.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: _mapOptions ??= MapOptions(
                  initialCenter: centro,
                  initialZoom: 14,
                  onMapReady: _fitMapBounds,
                  onPositionChanged: (_, hasGesture) {
                    if (!hasGesture) return;
                    _autoEncuadre = false; // el conductor movió el mapa: no pelearle
                    if (_seguir) setState(() => _seguir = false);
                  },
                ),
                children: [
                  _tileLayer,
                  if (_routePoints.length > 1) PolylineLayer(polylines: _routePolylines),
                  MarkerLayer(markers: markers),
                  CapaVehiculos(vehiculos: vehiculoConductor),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Column(children: [
                _mapFab(Icons.zoom_out_map_rounded, 'Ver ruta completa', () {
                  setState(() => _seguir = false);
                  _autoEncuadre = true;
                  _fitMapBounds();
                }),
                const SizedBox(height: 8),
                _mapFab(Icons.my_location_rounded, 'Seguir mi posición', () {
                  setState(() => _seguir = true);
                  _centrarEnConductor();
                }, activo: _seguir),
              ]),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: c.maxHeight * 0.6),
                child: _buildPanelEstado(t, estado),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mapFab(IconData icon, String tooltip, VoidCallback onTap, {bool activo = false}) {
    return Material(
      color: activo ? _primaryBlue : _white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 22, color: activo ? _white : _textDark)),
        ),
      ),
    );
  }

  // ---- Panel inferior por estado ----

  /// Datos del viaje desplazables arriba; la acción principal siempre visible
  /// abajo.
  Widget _buildPanelEstado(Trip t, String estado) {
    final acciones = _accionesEstado(t, estado);
    return Container(
      key: _panelKey,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, -3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bannerEstado(t, estado),
                  const SizedBox(height: 10),
                  _clienteFila(t, estado),
                  const SizedBox(height: 10),
                  _rutaFilas(t, estado),
                  const SizedBox(height: 10),
                  _precioFila(t),
                ],
              ),
            ),
          ),
          if (acciones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: acciones),
            ),
        ],
      ),
    );
  }

  ({String titulo, String detalle, IconData icono, Color color}) _infoEstado(String estado) {
    switch (estado) {
      case TripStatus.aceptado:
        return (titulo: 'Conduce al punto de recogida', detalle: 'Avísale al cliente que vas en camino.', icono: Icons.navigation_rounded, color: _primaryBlue);
      case TripStatus.enCamino:
        return (titulo: 'En camino al origen', detalle: 'Confirma la llegada cuando estés en el punto de recogida.', icono: Icons.local_shipping_rounded, color: _primaryBlue);
      case TripStatus.llegada:
        return (titulo: 'Estás en el origen', detalle: 'Recibe la carga e inicia el viaje.', icono: Icons.inventory_2_rounded, color: _accentGreen);
      case TripStatus.enCurso:
        return _isNearDestination
            ? (titulo: 'Estás en el destino', detalle: 'Entrega la carga y finaliza el viaje.', icono: Icons.flag_rounded, color: _accentGreen)
            : (titulo: 'Viaje en curso', detalle: 'Conduce hacia el punto de entrega.', icono: Icons.route_rounded, color: _primaryBlue);
      case TripStatus.entregado:
        return (titulo: 'Carga entregada', detalle: 'Finaliza el viaje para que el cliente confirme.', icono: Icons.flag_rounded, color: _accentGreen);
      case TripStatus.esperaConfirmacion:
      case TripStatus.pendienteConfirmacion:
        return (titulo: 'Esperando al cliente', detalle: 'El cliente debe confirmar la entrega para cerrar el viaje.', icono: Icons.hourglass_top_rounded, color: const Color(0xFFEF6C00));
      case TripStatus.sos:
        // Soporte (admin/moderador) resuelve la emergencia y devuelve el viaje
        // a su estado (o lo cierra/cancela): trip_state_machine 'sos'.
        return (titulo: 'Emergencia activa', detalle: 'Soporte fue notificado y te contactará. El viaje sigue cuando soporte cierre la emergencia.', icono: Icons.emergency_rounded, color: Colors.red.shade700);
      default:
        return (titulo: TripStatus.label(estado), detalle: '', icono: Icons.info_outline, color: _textGrey);
    }
  }

  Widget _bannerEstado(Trip t, String estado) {
    final info = _infoEstado(estado);
    final antes = _antesDeRecoger(estado);
    final d = antes ? _distOrigenKm : _distDestinoKm;
    final muestraDistancia = antes || estado == TripStatus.enCurso || estado == TripStatus.entregado;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: info.color, borderRadius: BorderRadius.circular(12)),
            child: Icon(info.icono, color: _white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(info.titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
            if (info.detalle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(info.detalle, style: const TextStyle(fontSize: 12, color: _textGrey, height: 1.3)),
            ],
          ])),
        ]),
        if (muestraDistancia) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(d == null ? Icons.gps_off_rounded : Icons.near_me_rounded, size: 16, color: d == null ? _textGrey : info.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                d == null
                    ? 'Buscando señal GPS…'
                    // Por la ruta del backend si es de esta fase (los avisos
                    // de 1 km siguen en recta, como valida el backend).
                    : '${_fmtDist(_etaFase == _faseActual && _restanteServidorM != null && (antes == (_faseActual == 'recogida')) ? _restanteServidorM! / 1000 : d)} '
                        '${antes ? 'al origen' : 'al destino'}  ·  ${_fmtEta(d)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: d == null ? _textGrey : _textDark),
              ),
            ),
            if (estado == TripStatus.enCurso || estado == TripStatus.entregado)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, size: 14, color: _primaryBlue),
                const SizedBox(width: 4),
                ValueListenableBuilder<int>(
                  valueListenable: _elapsed,
                  builder: (_, _, _) => Text(_formatElapsed(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _primaryBlue)),
                ),
              ]),
          ]),
        ],
      ]),
    );
  }

  Widget _clienteFila(Trip t, String estado) {
    final cliente = t.cliente;
    final nombre = cliente?.nombre ?? 'Cliente';
    final rating = cliente?.calificacion;
    return Row(children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFD1FAE5),
        child: Text(_initials(nombre), style: const TextStyle(color: Color(0xFF15803D), fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Row(children: [
          if (rating != null) ...[
            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
            const SizedBox(width: 6),
          ],
          const Text('Cliente', style: TextStyle(fontSize: 12, color: _textGrey)),
        ]),
      ])),
      if (TripStatus.chatHabilitado(estado))
        _iconoRedondo(Icons.chat_bubble_outline_rounded, 'Chat', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TripChatScreen(trip: t.toJson())));
        }),
      const SizedBox(width: 8),
      _iconoRedondo(Icons.phone_outlined, 'Llamar', () => _showClientPhone(t)),
    ]);
  }

  Widget _iconoRedondo(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _bgLight,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: _primaryDark)),
        ),
      ),
    );
  }

  Widget _rutaFilas(Trip t, String estado) {
    final antes = _antesDeRecoger(estado);
    return Column(children: [
      _rutaFila(Icons.trip_origin, const Color(0xFF16A34A), 'Origen', t.origen?.direccion ?? '', destacada: antes),
      const SizedBox(height: 6),
      _rutaFila(Icons.location_on, const Color(0xFFEF4444), 'Destino', t.destino?.direccion ?? '', destacada: !antes),
    ]);
  }

  Widget _rutaFila(IconData icon, Color color, String label, String dir, {required bool destacada}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _textGrey)),
        Text(
          dir.isEmpty ? '--' : dir,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: destacada ? FontWeight.w600 : FontWeight.w400, color: destacada ? _textDark : _textGrey),
        ),
      ])),
    ]);
  }

  Widget _precioFila(Trip t) {
    final precio = t.precioFinal ?? t.precioEstimado;
    final carga = t.carga ?? t.descripcion;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Precio acordado', style: TextStyle(fontSize: 11, color: _textGrey)),
          Text(_fmtPrecio(precio), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _primaryDark)),
        ])),
        if (carga != null && carga.isNotEmpty)
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Carga', style: TextStyle(fontSize: 11, color: _textGrey)),
            Text(carga, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
          ])),
      ]),
    );
  }

  /// Acción principal (y avisos) de cada estado. Las transiciones son las del
  /// backend: confirm-arrival -> conductor_en_camino, confirm-pickup ->
  /// conductor_llegada, start-trip -> en_curso, complete -> pendiente_confirmacion.
  List<Widget> _accionesEstado(Trip t, String estado) {
    switch (estado) {
      case TripStatus.aceptado:
        return [_botonPrincipal('Voy en camino al origen', Icons.navigation_rounded, _confirmArrival, _primaryDark)];
      case TripStatus.enCamino:
        return [
          ..._avisoOrigen('confirmar la llegada'),
          _botonPrincipal('Llegué al origen', Icons.where_to_vote_rounded, _lejosDelOrigen ? null : _confirmPickup, _primaryDark),
        ];
      case TripStatus.llegada:
        return [
          ..._avisoOrigen('iniciar el viaje'),
          _botonPrincipal('Iniciar viaje', Icons.play_arrow_rounded, _lejosDelOrigen ? null : _startTrip, _accentGreen),
        ];
      case TripStatus.enCurso:
      case TripStatus.entregado:
        return [
          ..._avisoDestino(),
          _botonFoto(),
          const SizedBox(height: 8),
          _botonPrincipal('Finalizar viaje', Icons.flag_rounded, _requestFinalization, _isNearDestination ? _accentGreen : _primaryBlue),
        ];
      case TripStatus.esperaConfirmacion:
      case TripStatus.pendienteConfirmacion:
        // Sólo el cliente confirma la entrega (confirm-close exige rol
        // cliente): el conductor espera y puede consultar el estado real.
        return [
          if (_deliveryPhotoUrl != null) ...[_avisoFotoLista(), const SizedBox(height: 8)],
          ValueListenableBuilder<ReglasCliente>(
            valueListenable: ConfigClienteService.instance.reglas,
            builder: (_, reglas, _) => EsperandoConfirmacionCliente(
              minutosRevision: reglas.confirmacionTimeoutMin,
              cargando: _actionLoading,
              onActualizar: _finalizeTrip,
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  List<Widget> _avisoOrigen(String accion) {
    final d = _distOrigenKm;
    if (d == null) {
      return [
        _aviso(Icons.gps_off_rounded, 'Sin señal GPS todavía. El servidor comprobará tu ubicación al $accion.', Colors.blueGrey),
        const SizedBox(height: 8),
      ];
    }
    if (d >= _radioKm) {
      return [
        _aviso(
          Icons.warning_amber_rounded,
          'Estás a ${_fmtDist(d)} del origen. Acércate a menos de ${_fmtRadio(_radioKm)} para $accion.',
          Colors.amber,
          accion: 'Actualizar GPS',
          onAccion: _refrescarUbicacion,
        ),
        const SizedBox(height: 8),
      ];
    }
    return const [];
  }

  /// Pide una posición nueva al GPS (por si el flujo va con retraso) y
  /// reenvía la ubicación al backend.
  Future<void> _refrescarUbicacion() async {
    await _actualizarUbicacionParaCierre();
    if (!mounted) return;
    setState(() {});
    _lastLocationSent = null;
    _sendLocation();
  }

  List<Widget> _avisoDestino() {
    final d = _distDestinoKm;
    if (d == null) {
      return [
        _aviso(Icons.gps_off_rounded, 'Sin señal GPS. Al finalizar se te pedirá una justificación del cierre.', Colors.blueGrey),
        const SizedBox(height: 8),
      ];
    }
    if (d >= _radioKm) {
      return [
        _aviso(Icons.info_outline_rounded, 'Estás a ${_fmtDist(d)} del destino. Fuera de ${_fmtRadio(_radioKm)} el cierre requiere una justificación.', Colors.amber),
        const SizedBox(height: 8),
      ];
    }
    return const [];
  }

  Widget _aviso(IconData icon, String texto, MaterialColor color, {String? accion, VoidCallback? onAccion}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.shade200)),
      child: Row(children: [
        Icon(icon, size: 18, color: color.shade800),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: color.shade900, height: 1.3))),
        if (accion != null && onAccion != null)
          TextButton(
            onPressed: onAccion,
            style: TextButton.styleFrom(
              foregroundColor: color.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(accion, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _avisoFotoLista() => _aviso(Icons.check_circle_rounded, 'Foto de entrega subida como evidencia.', Colors.green);

  Widget _botonFoto() {
    final lista = _deliveryPhotoUrl != null;
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _actionLoading ? null : _subirFotoEntrega,
        icon: Icon(lista ? Icons.check_circle_rounded : Icons.photo_camera_outlined, size: 20),
        label: Text(lista ? 'Foto de entrega lista (tomar otra)' : 'Tomar foto de entrega'),
        style: OutlinedButton.styleFrom(
          foregroundColor: lista ? const Color(0xFF15803D) : _primaryBlue,
          side: BorderSide(color: lista ? const Color(0xFF15803D) : _primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _subirFotoEntrega() async {
    // _takeDeliveryPhoto ya muestra el error del backend si falla.
    final url = await _takeDeliveryPhoto();
    if (url != null && mounted) {
      setState(() => _deliveryPhotoUrl = url);
      _snack('Foto de evidencia subida correctamente');
    }
  }

  Widget _botonPrincipal(String label, IconData icon, VoidCallback? onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: (_actionLoading || onPressed == null) ? null : onPressed,
        icon: _actionLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  /// Barra fija: Chat, Llamar, SOS y "Más" (detalle del cliente, reportar y
  /// cancelar según el estado). Antes eran seis botones apretados.
  Widget _buildBottomNav(Trip t, String estado) {
    return BarraInferiorFija(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _navItem(Icons.chat_bubble_outline, 'Chat', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TripChatScreen(trip: t.toJson())));
        }),
        _navItem(Icons.phone_outlined, 'Llamar', () => _showClientPhone(t)),
        _navItem(Icons.emergency_outlined, 'SOS', () {
          // Con el viaje: el backend lo pasa a 'sos', avisa al cliente y
          // los moderadores ven el caso con su viaje y zona.
          Navigator.push(context, MaterialPageRoute(builder: (_) => SOSAlertScreen(tripId: t.id)));
        }, color: const Color(0xFFDC2626)),
        _navItem(Icons.more_horiz_rounded, 'Más', () => _mostrarMasAcciones(t, estado), key: const Key('btn_mas_acciones')),
      ]),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap, {Color color = _textGrey, Key? key}) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: color, height: 1.1, fontWeight: color == _textGrey ? FontWeight.normal : FontWeight.w700)),
        ]),
      ),
    );
  }

  /// Hoja inferior con el resto de acciones del viaje.
  void _mostrarMasAcciones(Trip t, String estado) {
    final puedeCancelar = estado == TripStatus.aceptado || estado == TripStatus.enCamino;
    final pideCancelacion = estado == TripStatus.enCurso || estado == TripStatus.llegada;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            ListTile(
              key: const Key('accion_detalle_cliente'),
              leading: const Icon(Icons.info_outline, color: _primaryBlue),
              title: const Text('Información del cliente'),
              onTap: () {
                Navigator.pop(ctx);
                _showClientDetail(t);
              },
            ),
            ListTile(
              key: const Key('accion_reportar'),
              leading: const Icon(Icons.gavel_outlined, color: _primaryBlue),
              title: const Text('Reportar un problema'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeScreen(trip: t.toJson(), role: 'conductor')));
              },
            ),
            if (puedeCancelar)
              ListTile(
                key: const Key('accion_cancelar'),
                leading: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
                title: const Text('Cancelar viaje', style: TextStyle(color: Color(0xFFDC2626))),
                onTap: () {
                  Navigator.pop(ctx);
                  _cancelTrip(t);
                },
              ),
            if (pideCancelacion)
              ListTile(
                key: const Key('accion_solicitar_cancelacion'),
                leading: const Icon(Icons.report_problem_outlined, color: Color(0xFFDC2626)),
                title: const Text('Solicitar cancelación', style: TextStyle(color: Color(0xFFDC2626))),
                subtitle: const Text('En este estado la cancelación requiere aprobación.'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!_isCancelling) _requestCancellation(t);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showClientPhone(Trip t) {
    final cliente = t.cliente;
    final nombre = cliente?.nombre ?? 'Cliente';
    final telefono = cliente?.telefono;
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

  void _showClientDetail(Trip t) {
    final cliente = t.cliente;
    if (cliente == null) {
      _snack('No hay informaci\u00f3n del cliente disponible');
      return;
    }
    final nombre = cliente.nombre ?? 'Sin nombre';
    final telefono = cliente.telefono;
    final calificacion = cliente.calificacion;
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
                  final val = calificacion.toInt();
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

  Future<void> _cancelTrip(Trip t) async {
    final estado = t.estado;
    // El backend (trip_controller.cancel) NO permite cancelar directamente en
    // 'en_curso' ni en 'conductor_llegada' (403) -> usar solicitud de cancelación.
    if (estado == TripStatus.enCurso || estado == TripStatus.llegada) {
      _snack('El viaje en este estado requiere aprobaci\u00f3n. Se enviar\u00e1 una solicitud de cancelaci\u00f3n.');
      _requestCancellation(t);
      return;
    }
    final motivoCtrl = TextEditingController();
    String? motivoSeleccionado;
    String? justificacion;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          // Con el teclado abierto, "Cancelar viaje" quedaba encima del campo
          // de justificación: el contenido ahora se desplaza.
          scrollable: true,
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
              RadioGroup<String>(
                groupValue: motivoSeleccionado,
                onChanged: (v) => setDialogState(() => motivoSeleccionado = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in const ['Problema con el cliente', 'Veh\u00edculo no disponible', 'Emergencia', 'Otro'])
                      RadioListTile<String>(
                        title: Text(m, style: const TextStyle(fontSize: 14)),
                        value: m,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              if (motivoSeleccionado != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Justificaci\u00f3n (m\u00ednimo 10 caracteres)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: (v) {
                    justificacion = v.trim();
                    setDialogState(() {});
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            ElevatedButton(
              onPressed: (motivoSeleccionado != null && justificacion != null && justificacion!.length >= 10)
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              child: const Text('Cancelar viaje'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || motivoSeleccionado == null || justificacion == null || justificacion!.length < 10) {
      return;
    }

    FraudDetectionService.instance.checkCancellation(ApiClient.instance.userId ?? '');

    try {
      final desc = motivoCtrl.text.trim();
      final motivo = desc.isNotEmpty ? '$motivoSeleccionado: $desc' : motivoSeleccionado;
      await DriverLocationService.instance.conUbicacionFresca(() => ApiClient.instance.cancelTrip(t.id, motivo: motivo, justificacion: justificacion));
      if (mounted) {
        _snack('Viaje cancelado. Se ha notificado al cliente.');
        _salirDelViaje();
      }
    } on ApiException catch (e) {
      if (e.code == 'CONDUCTOR_CERCA') {
        _snack('No se puede cancelar: el conductor est\u00e1 a menos de 1 km del origen.');
      } else if (e.code == 'JUSTIFICACION_REQUERIDA') {
        _snack('Justificaci\u00f3n requerida (m\u00ednimo 10 caracteres).');
      } else {
        _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  Future<void> _requestCancellation(Trip t) async {
    if (_isCancelling) return;
    _isCancelling = true;

    final motivoCtrl = TextEditingController();
    String? motivoSeleccionado;

    try {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            scrollable: true,
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
                    // El backend avisa s\u00f3lo a soporte (admin:cancellation_requested);
                    // el cliente se entera si soporte la aprueba.
                    Expanded(child: Text('El viaje est\u00e1 en curso: soporte revisar\u00e1 tu solicitud. Mientras tanto el viaje sigue activo.', style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500))),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Motivo de la solicitud:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: motivoSeleccionado,
                  onChanged: (v) => setDialogState(() => motivoSeleccionado = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final m in const ['Problema con el cliente', 'Emergencia', 'Veh\u00edculo averiado', 'Otro'])
                        RadioListTile<String>(
                          title: Text(m, style: const TextStyle(fontSize: 14)),
                          value: m,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
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
      await ApiClient.instance.requestCancellation(t.id, motivo: motivo);
      if (mounted) {
        _snack('Solicitud enviada a soporte. Si la aprueba, el viaje se cancela y se avisa al cliente.');
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
