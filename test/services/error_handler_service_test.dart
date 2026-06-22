import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/services/error_handler_service.dart';

void main() {
  group('ErrorHandlerService', () {
    late ErrorHandlerService service;

    setUp(() {
      service = ErrorHandlerService.instance;
    });

    tearDown(() {});

    group('init', () {
      test('initializes once without throwing', () {
        service.init();
        expect(() => service.init(), returnsNormally);
      });
    });

    group('handleError', () {
      test('emits error events on stream', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);
        final stack = StackTrace.current;

        service.handleError('test error', stack);

        await Future(() {});
        expect(events.length, 1);
        expect(events.first.category, ErrorCategory.general);
        expect(events.first.fatal, isFalse);
        expect(events.first.message, 'Ocurri\u00f3 un error inesperado.');
        expect(events.first.error, 'test error');
        expect(events.first.timestamp, isA<DateTime>());

        await sub.cancel();
      });

      test('categorizes errors correctly', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);

        service.handleError('net err', StackTrace.current,
            category: ErrorCategory.network);

        await Future(() {});
        expect(events.first.category, ErrorCategory.network);
        expect(events.first.message,
            'Error de conexi\u00f3n. Verifica tu internet.');

        await sub.cancel();
      });

      test('sets fatal flag and message', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);

        service.handleError('fatal error', null,
            fatal: true, category: ErrorCategory.auth);

        await Future(() {});
        expect(events.first.fatal, isTrue);
        expect(events.first.category, ErrorCategory.auth);
        expect(events.first.message,
            'Error de autenticaci\u00f3n. Inicia sesi\u00f3n nuevamente.');

        await sub.cancel();
      });

      test('uses custom message when provided', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);

        service.handleError('err', StackTrace.current,
            message: 'Custom message');

        await Future(() {});
        expect(events.first.message, 'Custom message');

        await sub.cancel();
      });

      test('gps category uses correct icon message', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);

        service.handleError('gps err', StackTrace.current,
            category: ErrorCategory.gps);

        await Future(() {});
        expect(events.first.category, ErrorCategory.gps);
        expect(events.first.message,
            'Error de ubicaci\u00f3n. Verifica tu GPS.');

        await sub.cancel();
      });

      test('socket category uses correct message', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);

        service.handleError('socket err', StackTrace.current,
            category: ErrorCategory.socket);

        await Future(() {});
        expect(events.first.message,
            'Error de conexi\u00f3n en tiempo real. Reintentando...');

        await sub.cancel();
      });

      test('map category uses correct message', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);

        service.handleError('map err', StackTrace.current,
            category: ErrorCategory.map);

        await Future(() {});
        expect(events.first.message, 'Error al cargar el mapa.');

        await sub.cancel();
      });
    });

    group('safeAsync', () {
      test('returns result when function succeeds', () async {
        final result = await service.safeAsync(() async => 42);
        expect(result, 42);
      });

      test('returns fallback when function throws', () async {
        final result = await service.safeAsync(
          () async => throw Exception('fail'),
          fallback: -1,
          category: ErrorCategory.network,
        );
        expect(result, -1);
      });

      test('emits error on stream when function throws', () async {
        final events = <ErrorEvent>[];
        final sub = service.onError.listen(events.add);

        await service.safeAsync(
          () async => throw Exception('async fail'),
          fallback: null,
        );

        await Future(() {});
        expect(events.length, 1);
        expect(events.first.error.toString(), contains('async fail'));

        await sub.cancel();
      });
    });

    group('safeSync', () {
      test('returns result when function succeeds', () {
        final result = service.safeSync(() => 42, fallback: -1);
        expect(result, 42);
      });

      test('returns fallback when function throws', () {
        final result = service.safeSync(
          () => throw Exception('sync fail'),
          fallback: -1,
          category: ErrorCategory.gps,
        );
        expect(result, -1);
      });
    });

    group('safeStream', () {
      test('forwards values from source stream', () {
        final source = Stream.value(42);
        final safe = service.safeStream<int>(source);
        expect(safe, emits(42));
      });

      test('handles errors without propagating them', () {
        final source = Stream<int>.error(Exception('stream error'));
        final safe = service.safeStream<int>(source);
        expect(safe, emitsDone);
      });

      test('forwards multiple values', () {
        final source = Stream<int>.fromIterable([1, 2, 3]);
        final safe = service.safeStream<int>(source);
        expect(safe, emitsInOrder([1, 2, 3]));
      });
    });

    group('dispose', () {
      test('closes stream controller', () async {
        final done = service.onError.drain<void>();
        service.dispose();
        await done; // should complete without hanging
      });

      test('handleError does not crash after dispose', () {
        service.dispose();
        expect(
          () => service.handleError('after dispose', StackTrace.current),
          returnsNormally,
        );
      });

      test('calling dispose twice does not throw', () {
        service.dispose();
        expect(() => service.dispose(), returnsNormally);
      });
    });
  });
}
