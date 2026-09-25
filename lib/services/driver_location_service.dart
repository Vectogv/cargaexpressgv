import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_client.dart';
import 'api/http_client.dart' show ApiException;
import 'background_location_service.dart';
import 'fraud_detection_service.dart';
import 'logger_service.dart';
import 'network_monitor_service.dart';
import 'error_handler_service.dart';
import 'solicitudes_disponibles_service.dart';

/// GPS del conductor en línea: envía su posición al backend y mantiene
/// activa la lista de solicitudes disponibles ([SolicitudesDisponiblesService],
/// que sondea GET /api/trips/nearby con la última posición conocida).
class DriverLocationService {
  static final DriverLocationService instance = DriverLocationService._();
  DriverLocationService._();

  StreamSubscription<Position>? _positionSub;
  double? _lastLat;
  double? _lastLng;
  bool _running = false;
  int _locationErrorCount = 0;
  int _locationRetryAttempt = 0;
  Timer? _retryPositionTimer;
  DateTime _lastLocationSent = DateTime(2000);

  bool get isRunning => _running;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

  Future<bool> start() async {
    if (_running) return true;
    _running = true;

    final granted = await _requestLocationPermission();
    if (!granted) {
      _running = false;
      LoggerService.instance.warning('DriverLocationService: location permission denied');
      return false;
    }

    _startPositionStream();
    await _sendInitialLocation();
    _iniciarSolicitudes();

    if (!kIsWeb) {
      // Android 13+: sin este permiso no se ve el aviso "Enviando ubicación".
      // Si lo niega, igual se conecta.
      await _requestNotificationPermission();
      try {
        await BackgroundLocationService.instance.initialize();
        await BackgroundLocationService.instance.start();
      } catch (e) {
        LoggerService.instance.error('DriverLocationService: background location start error', e);
      }
    }
    return true;
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    _retryPositionTimer?.cancel();
    _locationErrorCount = 0;
    _locationRetryAttempt = 0;

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    try {
      _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position pos) async {
          _locationErrorCount = 0;
          _locationRetryAttempt = 0;
          FraudDetectionService.instance.checkGpsPosition(pos);
          _lastLat = pos.latitude;
          _lastLng = pos.longitude;
          await _sendLocation(pos.latitude, pos.longitude);
        },
        onError: (e) {
          _locationErrorCount++;
          _locationRetryAttempt++;
          ErrorHandlerService.instance.handleError(
            e,
            null,
            category: ErrorCategory.gps,
            message: 'Error del GPS (intento $_locationRetryAttempt)',
          );
          if (_locationErrorCount > 5) {
            LoggerService.instance.warning('DriverLocationService: too many position errors, restarting stream');
            _positionSub?.cancel();
            final delay = Duration(seconds: min(pow(2, _locationRetryAttempt).toInt(), 30));
            _retryPositionTimer = Timer(delay, _startPositionStream);
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _locationRetryAttempt++;
      ErrorHandlerService.instance.handleError(
        e,
        null,
        category: ErrorCategory.gps,
        message: 'Error al crear stream de ubicaci\u00f3n',
      );
      final delay = Duration(seconds: min(pow(2, _locationRetryAttempt).toInt(), 30));
      _retryPositionTimer = Timer(delay, _startPositionStream);
    }
  }

  Future<void> _sendLocation(double lat, double lng) async {
    final now = DateTime.now();
    if (now.difference(_lastLocationSent).inSeconds < 5) return;
    _lastLocationSent = now;
    if (!NetworkMonitorService.instance.isOnline) return;
    try {
      await ApiClient.instance.updateLocation(lat, lng);
    } catch (e) {
      ErrorHandlerService.instance.handleError(
        e,
        null,
        category: ErrorCategory.network,
        message: 'Error al enviar ubicaci\u00f3n',
      );
    }
  }

  Future<void> _sendInitialLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        // Con límite: sin señal GPS la llamada nunca terminaría.
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      await _sendLocation(pos.latitude, pos.longitude);
    } catch (e) {
      LoggerService.instance.error('DriverLocationService._sendInitialLocation error', e);
    }
  }

  /// Con la posición ya conocida, la lista de solicitudes se (re)consulta con
  /// ella. Si el inicio ya la había activado sin GPS, sólo se sincroniza.
  void _iniciarSolicitudes() {
    final solicitudes = SolicitudesDisponiblesService.instance;
    if (solicitudes.activo) {
      unawaited(solicitudes.sincronizar());
    } else {
      solicitudes.iniciar();
    }
  }

  /// Desconectado o cierre de sesión: detiene también el servicio de ubicación
  /// en segundo plano (a diferencia de [pause], que lo deja activo durante un
  /// viaje).
  void stop() {
    _running = false;
    _positionSub?.cancel();
    _positionSub = null;
    _retryPositionTimer?.cancel();
    _retryPositionTimer = null;
    _locationRetryAttempt = 0;
    _locationErrorCount = 0;
    SolicitudesDisponiblesService.instance.detener();
    if (!kIsWeb) unawaited(BackgroundLocationService.instance.stop());
  }

  /// Durante un viaje: el conductor está ocupado y el backend no le deja
  /// ofertar (CONDUCTOR_OCUPADO), así que la lista de solicitudes se detiene.
  void pause() {
    _running = false;
    SolicitudesDisponiblesService.instance.detener();
    _positionSub?.cancel();
    _positionSub = null;
    _retryPositionTimer?.cancel();
    _retryPositionTimer = null;
    _locationRetryAttempt = 0;
    _locationErrorCount = 0;
  }

  void resume() {
    // pause() pone _running = false; resume() debe volver a activar el
    // servicio (antes se abortaba silenciosamente y nunca se reanudaba).
    _running = true;
    if (_lastLat != null && _lastLng != null) {
      _startPositionStream();
    } else {
      _sendInitialLocation();
      _startPositionStream();
    }
    _iniciarSolicitudes();
  }

  Future<bool> _requestLocationPermission() async {
    try {
      var status = await Permission.location.status;
      if (status.isGranted) return true;
      status = await Permission.location.request();
      if (status.isGranted) return true;

      if (await Permission.locationAlways.request().isGranted) return true;
      if (await Permission.location.isGranted) return true;

      return false;
    } catch (e) {
      LoggerService.instance.error('DriverLocationService permission error', e);
      return false;
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (await Permission.notification.isGranted) return;
      await Permission.notification.request();
    } catch (e) {
      LoggerService.instance.error('DriverLocationService notification permission error', e);
    }
  }

  void dispose() {
    stop();
  }

  /// Toma el GPS actual y lo envía al backend ya (sin el throttle de 5 s).
  /// Si el backend limita la frecuencia (429), espera y reintenta una vez.
  Future<void> sendNow() async {
    final pos = await Geolocator.getCurrentPosition(
      // Con límite: sin señal GPS la llamada nunca terminaría.
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    _lastLat = pos.latitude;
    _lastLng = pos.longitude;
    try {
      await ApiClient.instance.updateLocation(pos.latitude, pos.longitude);
    } on ApiException catch (e) {
      if (e.statusCode != 429) rethrow;
      await Future.delayed(const Duration(milliseconds: 4500));
      await ApiClient.instance.updateLocation(pos.latitude, pos.longitude);
    }
    _lastLocationSent = DateTime.now();
  }

  /// Ejecuta una acción del conductor que valida su ubicación en el backend
  /// (ofertar, recoger, cerrar, cancelar). Si responde UBICACION_NO_RECIENTE,
  /// envía el GPS actual y reintenta una sola vez.
  Future<T> conUbicacionFresca<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ApiException catch (e) {
      if (e.code != 'UBICACION_NO_RECIENTE') rethrow;
      await sendNow();
      return accion();
    }
  }
}
