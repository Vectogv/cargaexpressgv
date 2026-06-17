import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_client.dart';
import 'background_location_service.dart';

class DriverLocationService {
  static final DriverLocationService instance = DriverLocationService._();
  DriverLocationService._();

  Timer? _tripPollTimer;
  StreamSubscription<Position>? _positionSub;
  double? _lastLat;
  double? _lastLng;
  bool _running = false;
  bool _online = false;

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
      return;
    }

    _startPositionStream();
    await _sendInitialLocation();
    await _fetchNearbyTrips();
    _startTripPolling();

    await BackgroundLocationService.instance.initialize();
    await BackgroundLocationService.instance.start();
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
      timeLimit: const Duration(seconds: 30),
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position pos) async {
        _lastLat = pos.latitude;
        _lastLng = pos.longitude;
        try {
          await ApiClient.instance.updateLocation(pos.latitude, pos.longitude);
        } catch (_) {}
      },
      onError: (_) {},
    );
  }

  Future<void> _sendInitialLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      await ApiClient.instance.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  void _startTripPolling() {
    _tripPollTimer?.cancel();
    _tripPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchNearbyTrips());
  }

  Future<void> _fetchNearbyTrips() async {
    if (!_online || _lastLat == null || _lastLng == null) return;
    try {
      final trips = await ApiClient.instance.getNearbyTrips(_lastLat!, _lastLng!, radio: 20);
      if (!_online) return;
      _nearbyTrips = trips;
      if (!_tripStreamController.isClosed) {
        _tripStreamController.add(List.from(trips));
      }
    } catch (_) {}
  }

  void stop() {
    _running = false;
    _online = false;
    _positionSub?.cancel();
    _positionSub = null;
    _tripPollTimer?.cancel();
    _tripPollTimer = null;
    _nearbyTrips = [];
  }

  void pause() {
    _online = false;
    _tripPollTimer?.cancel();
    _tripPollTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
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
    var status = await Permission.location.status;
    if (status.isGranted) return true;
    status = await Permission.location.request();
    if (status.isGranted) return true;

    if (await Permission.locationAlways.request().isGranted) return true;
    if (await Permission.location.isGranted) return true;

    return false;
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
