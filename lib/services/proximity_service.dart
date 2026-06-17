import 'dart:async';
import 'dart:math';
import 'api_client.dart';

class ProximityService {
  Timer? _timer;
  bool _nearOriginNotified = false;
  bool _nearDestinyNotified = false;
  bool _monitoring = false;

  static const double proximityRadius = 500;

  void startMonitoring(Map<String, dynamic> trip, void Function(String message) onAlert) {
    if (_monitoring) return;
    _monitoring = true;
    _nearOriginNotified = false;
    _nearDestinyNotified = false;
    _checkProximity(trip, onAlert);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshAndCheck(trip, onAlert);
    });
  }

  Future<void> _refreshAndCheck(Map<String, dynamic> trip, void Function(String message) onAlert) async {
    try {
      final updated = await ApiClient.instance.getActiveTrip();
      if (updated != null) {
        _checkProximity(updated, onAlert);
      }
    } catch (_) {}
  }

  void _checkProximity(Map<String, dynamic> trip, void Function(String message) onAlert) {
    final conductor = trip['conductor'] as Map<String, dynamic>?;
    if (conductor == null) return;

    final driverLat = _parseDouble(conductor['lat']);
    final driverLng = _parseDouble(conductor['lng']);
    if (driverLat == null || driverLng == null) return;

    final origen = trip['origen'] as Map<String, dynamic>?;
    final destino = trip['destino'] as Map<String, dynamic>?;

    if (!_nearOriginNotified && origen != null) {
      final oLat = _parseDouble(origen['lat']);
      final oLng = _parseDouble(origen['lng']);
      if (oLat != null && oLng != null) {
        final dist = _calculateDistance(driverLat, driverLng, oLat, oLng);
        if (dist <= proximityRadius) {
          _nearOriginNotified = true;
          onAlert('El conductor designado est\u00e1 cerca de tu ubicaci\u00f3n.');
        }
      }
    }

    if (!_nearDestinyNotified && destino != null) {
      final dLat = _parseDouble(destino['lat']);
      final dLng = _parseDouble(destino['lng']);
      if (dLat != null && dLng != null) {
        final dist = _calculateDistance(driverLat, driverLng, dLat, dLng);
        if (dist <= proximityRadius) {
          _nearDestinyNotified = true;
          onAlert('El conductor se encuentra cerca del destino de tu carga.');
        }
      }
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _monitoring = false;
    _nearOriginNotified = false;
    _nearDestinyNotified = false;
  }

  bool get isMonitoring => _monitoring;
}
