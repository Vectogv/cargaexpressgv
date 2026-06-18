import 'dart:async';
import 'dart:math';
import 'api/http_client.dart';
import 'logger_service.dart';
import 'package:geolocator/geolocator.dart';

enum FraudType {
  gpsSpoof,
  multipleAccounts,
  excessiveCancellations,
  suspiciousActivity,
  fraudulentTrip,
}

class FraudAlert {
  final FraudType type;
  final String severity;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const FraudAlert({
    required this.type,
    required this.severity,
    required this.message,
    required this.data,
    required this.timestamp,
  });
}

class FraudDetectionService {
  static final FraudDetectionService instance = FraudDetectionService._();
  FraudDetectionService._();

  final StreamController<FraudAlert> _alertCtrl = StreamController<FraudAlert>.broadcast();
  Stream<FraudAlert> get onFraudAlert => _alertCtrl.stream;

  // GPS spoof detection
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastTimestamp;
  int _gpsJumpCount = 0;
  int _gpsAccuracyWarnings = 0;

  // Cancellation tracking
  final Map<String, List<DateTime>> _cancellations = {};
  static const int _maxCancellationsPerWindow = 5;
  static const Duration _cancellationWindow = Duration(hours: 1);

  // Activity tracking
  final Map<String, List<DateTime>> _rapidTransitions = {};
  static const Duration _minTripDuration = Duration(minutes: 2);

  FraudAlert? checkGpsPosition(Position pos) {
    final now = DateTime.now();
    if (_lastLat == null || _lastLng == null || _lastTimestamp == null) {
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastTimestamp = now;
      return null;
    }

    final distance = Geolocator.distanceBetween(
      _lastLat!, _lastLng!, pos.latitude, pos.longitude,
    );
    final timeDiff = now.difference(_lastTimestamp!).inSeconds;

    _lastLat = pos.latitude;
    _lastLng = pos.longitude;
    _lastTimestamp = now;

    // Impossible speed: > 300 m/s (~1080 km/h) is impossible for ground transport
    if (timeDiff > 0 && distance / timeDiff > 300) {
      _gpsJumpCount++;
      if (_gpsJumpCount >= 3) {
        _gpsJumpCount = 0;
        return _emitAlert(
          FraudType.gpsSpoof, 'high',
          'Posible GPS falso: salto imposible detectado',
          {'distance': distance, 'timeDiff': timeDiff, 'speed': distance / timeDiff},
        );
      }
    } else {
      _gpsJumpCount = max(0, _gpsJumpCount - 1);
    }

    // Suspicious accuracy: > 500m
    if (pos.accuracy > 500 && pos.accuracy < 9999) {
      _gpsAccuracyWarnings++;
      if (_gpsAccuracyWarnings >= 5) {
        _gpsAccuracyWarnings = 0;
        return _emitAlert(
          FraudType.gpsSpoof, 'medium',
          'Precisi\u00f3n GPS sospechosa: ${pos.accuracy.toStringAsFixed(0)}m',
          {'accuracy': pos.accuracy},
        );
      }
    } else {
      _gpsAccuracyWarnings = max(0, _gpsAccuracyWarnings - 1);
    }

    return null;
  }

  FraudAlert? checkCancellation(String userId) {
    final now = DateTime.now();
    _cancellations.putIfAbsent(userId, () => []);
    _cancellations[userId]!.retainWhere((t) => now.difference(t) < _cancellationWindow);
    _cancellations[userId]!.add(now);

    if (_cancellations[userId]!.length >= _maxCancellationsPerWindow) {
      _cancellations[userId]!.clear();
      return _emitAlert(
        FraudType.excessiveCancellations, 'high',
        'Cancelaciones excesivas: ${_cancellations[userId]!.length} en 1 hora',
        {'userId': userId, 'count': _cancellations[userId]!.length},
      );
    }
    return null;
  }

  FraudAlert? checkTripTransition(String tripId, String fromState, String toState) {
    if (fromState == 'aceptado' && toState == 'completado') {
      _rapidTransitions.putIfAbsent(tripId, () => [DateTime.now(), DateTime.now()]);
    } else if (fromState == 'en_curso' && toState == 'completado') {
      final states = _rapidTransitions[tripId];
      if (states != null && states.length >= 2) {
        final duration = DateTime.now().difference(states[1]);
        if (duration < _minTripDuration) {
          return _emitAlert(
            FraudType.fraudulentTrip, 'high',
            'Viaje fraudulento: completado en ${duration.inSeconds}s',
            {'tripId': tripId, 'duration': duration.inSeconds},
          );
        }
      }
    }
    return null;
  }

  FraudAlert? checkSuspiciousActivity(String userId, String activity) {
    return _emitAlert(
      FraudType.suspiciousActivity, 'low',
      'Actividad sospechosa: $activity',
      {'userId': userId, 'activity': activity},
    );
  }

  void reportDeviceChange(String previousUserId, String newUserId) {
    _emitAlert(
      FraudType.multipleAccounts, 'high',
      'M\u00faltiples cuentas: mismo dispositivo usado por $previousUserId y $newUserId',
      {'previousUser': previousUserId, 'newUser': newUserId},
    );
  }

  FraudAlert _emitAlert(FraudType type, String severity, String message, Map<String, dynamic> data) {
    final alert = FraudAlert(
      type: type,
      severity: severity,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
    LoggerService.instance.warning('[FRAUD] $message');
    _sendAlertToServer(alert);
    _alertCtrl.add(alert);
    return alert;
  }

  Future<void> _sendAlertToServer(FraudAlert alert) async {
    try {
      await HttpClient.post('/api/fraud/alerts',
        body: {
          'type': alert.type.name,
          'severity': alert.severity,
          'message': alert.message,
          'data': alert.data,
          'timestamp': alert.timestamp.toIso8601String(),
        },
        auth: true,
      );
    } catch (e) {
      LoggerService.instance.debug('FraudDetectionService: failed to send alert to server: $e');
    }
  }

  void dispose() {
    _alertCtrl.close();
  }
}
