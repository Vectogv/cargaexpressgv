import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

/// Replica la lógica de throttling GPS de _sendLocation en
/// trip_in_progress_screen.dart (línea 601):
///
///   if (_lastLocationSent != null &&
///       DateTime.now().difference(_lastLocationSent!).inSeconds < 10)
///     return;
///
/// [trySendAt] acepta la hora actual explícitamente para facilitar
/// el testeo sin depender de DateTime.now().
class GpsThrottle {
  DateTime? _lastSent;
  int _callCount = 0;

  int get callCount => _callCount;

  bool trySendAt(DateTime now) {
    if (_lastSent != null && now.difference(_lastSent!).inSeconds < 10) {
      return false;
    }
    _lastSent = now;
    _callCount++;
    return true;
  }
}

void main() {
  group('Throttle de GPS (10s entre envíos)', () {
    test('primera llamada siempre pasa', () {
      final throttle = GpsThrottle();
      expect(throttle.trySendAt(DateTime(2025, 1, 1)), isTrue);
      expect(throttle.callCount, 1);
    });

    test('llamadas dentro de 10s son ignoradas', () {
      final throttle = GpsThrottle();
      final t0 = DateTime(2025, 6, 1, 12, 0, 0);

      expect(throttle.trySendAt(t0), isTrue);

      expect(throttle.trySendAt(t0.add(const Duration(seconds: 1))), isFalse);
      expect(throttle.trySendAt(t0.add(const Duration(seconds: 5))), isFalse);
      expect(throttle.trySendAt(t0.add(const Duration(seconds: 9))), isFalse);
      expect(throttle.callCount, 1);
    });

    test('después de 10s se permite un nuevo envío', () {
      final throttle = GpsThrottle();
      final t0 = DateTime(2025, 6, 1, 12, 0, 0);

      expect(throttle.trySendAt(t0), isTrue);
      expect(throttle.trySendAt(t0.add(const Duration(seconds: 10))), isTrue);
      expect(throttle.callCount, 2);
    });

    test('10 llamadas en 5s solo ejecuta 1', () {
      final throttle = GpsThrottle();
      final t0 = DateTime(2025, 6, 1, 12, 0, 0);

      expect(throttle.trySendAt(t0), isTrue);

      for (var i = 1; i <= 10; i++) {
        throttle.trySendAt(t0.add(Duration(milliseconds: i * 500)));
      }
      expect(throttle.callCount, 1);
    });

    test('envíos periódicos cada 10s son aceptados', () {
      final throttle = GpsThrottle();
      final t0 = DateTime(2025, 6, 1, 12, 0, 0);

      for (var i = 0; i < 5; i++) {
        expect(throttle.trySendAt(t0.add(Duration(seconds: i * 10))), isTrue);
      }
      expect(throttle.callCount, 5);
    });

    test('Timer.periodic cada 10s llama al callback', () {
      fakeAsync((async) {
        var callCount = 0;
        Timer.periodic(const Duration(seconds: 10), (_) => callCount++);

        async.elapse(const Duration(seconds: 5));
        expect(callCount, 0);

        async.elapse(const Duration(seconds: 5));
        expect(callCount, 1);

        async.elapse(const Duration(seconds: 10));
        expect(callCount, 2);

        async.elapse(const Duration(seconds: 20));
        expect(callCount, 4);
      });
    });
  });
}
