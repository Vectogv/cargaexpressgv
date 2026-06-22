import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_client.dart';
import 'background_location_service.dart';
import 'fraud_detection_service.dart';
import 'logger_service.dart';
import 'network_monitor_service.dart';
import 'error_handler_service.dart';

class DriverLocationService {
  static final DriverLocationService instance = DriverLocationService._();
  DriverLocationService._();

  Timer? _tripPollTimer;
  StreamSubscription<Position>? _positionSub;
  double? _lastLat;
  double? _lastLng;
  bool _running = false;
  bool _online = false;
  int _locationErrorCount = 0;
  int _locationRetryAttempt = 0;
  Timer? _retryPositionTimer;

  List<Map<String, dynamic>> _nearbyTrips = [];
  final _tripStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get onTripsUpdated => _tripStreamController.stream;
  List<Map<String, dynamic>> get nearbyTrips => List.unmodifiable(_nearbyTrips);
  bool get isRunning => _running;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _online = true;

    final granted = await _requestLocationPermission();
    if (!granted) {
      _running = false;
      LoggerService.instance.warning('DriverLocationService: location permission denied');
      return;
    }

    _startPositionStream();
    await _sendInitialLocation();
    await _fetchNearbyTrips();
    _startTripPolling();

    if (!kIsWeb) {
      try {
        await BackgroundLocationService.instance.initialize();
        await BackgroundLocationService.instance.start();
      } catch (e) {
        LoggerService.instance.error('DriverLocationService: background location start error', e);
      }
    }
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
          try {
            if (NetworkMonitorService.instance.isOnline) {
              await ApiClient.instance.updateLocation(pos.latitude, pos.longitude);
            }
          } catch (e) {
            ErrorHandlerService.instance.handleError(
              e,
              null,
              category: ErrorCategory.network,
              message: 'Error al enviar ubicaci\u00f3n',
            );
          }
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

  Future<void> _sendInitialLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      if (NetworkMonitorService.instance.isOnline) {
        await ApiClient.instance.updateLocation(pos.latitude, pos.longitude);
      }
    } catch (e) {
      LoggerService.instance.error('DriverLocationService._sendInitialLocation error', e);
    }
  }

  void _startTripPolling() {
    _tripPollTimer?.cancel();
    _tripPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchNearbyTrips());
  }

  Future<void> _fetchNearbyTrips() async {
    if (!_online || _lastLat == null || _lastLng == null) return;
    if (!NetworkMonitorService.instance.isOnline) return;
    try {
      final trips = await ApiClient.instance.getNearbyTrips(_lastLat!, _lastLng!, radio: 20);
      if (!_online) return;
      _nearbyTrips = trips;
      if (!_tripStreamController.isClosed) {
        _tripStreamController.add(List.from(trips));
      }
    } catch (e) {
      LoggerService.instance.debug('DriverLocationService._fetchNearbyTrips error: $e');
    }
  }

  void stop() {
    _running = false;
    _online = false;
    _positionSub?.cancel();
    _positionSub = null;
    _tripPollTimer?.cancel();
    _tripPollTimer = null;
    _retryPositionTimer?.cancel();
    _retryPositionTimer = null;
    _locationRetryAttempt = 0;
    _locationErrorCount = 0;
    _nearbyTrips = [];
  }

  void pause() {
    _online = false;
    _tripPollTimer?.cancel();
    _tripPollTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _retryPositionTimer?.cancel();
    _retryPositionTimer = null;
    _locationRetryAttempt = 0;
    _locationErrorCount = 0;
  }

  void resume() {
    if (!_running) return;
    _online = true;
    if (_lastLat != null && _lastLng != null) {
      _startPositionStream();
    } else {
      _sendInitialLocation();
      _startPositionStream();
    }
    _startTripPolling();
    _fetchNearbyTrips();
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

  void removeTrip(dynamic tripId) {
    _nearbyTrips.removeWhere((t) => t['id'] == tripId);
    if (!_tripStreamController.isClosed) {
      _tripStreamController.add(List.from(_nearbyTrips));
    }
  }

  void dispose() {
    stop();
    _tripStreamController.close();
  }
}
