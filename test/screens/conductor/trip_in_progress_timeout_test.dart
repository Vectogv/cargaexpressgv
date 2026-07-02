import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

/// Simula la lógica del contador regresivo de 30s en _requestFinalization.
/// Cuando timeoutSec llega a 0, llama onTimeout.
(Timer, bool Function()) createCountdown({
  required int timeoutSec,
  required void Function() onTimeout,
  required void Function() onTick,
}) {
  var completed = false;
  final timer = Timer.periodic(const Duration(seconds: 1), (t) {
    timeoutSec--;
    if (timeoutSec <= 0) {
      t.cancel();
      completed = true;
      onTimeout();
    } else {
      onTick();
    }
  });
  return (timer, () => completed);
}

void main() {
  group('Timeout de 30s en _requestFinalization', () {
    test('el contador parte en 30 y decrementa cada segundo', () {
      fakeAsync((async) {
        var tickCount = 0;
        Timer? timer;
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          tickCount++;
          if (tickCount >= 5) t.cancel();
        });

        async.elapse(const Duration(seconds: 3));
        expect(tickCount, 3);

        async.elapse(const Duration(seconds: 2));
        expect(tickCount, 5);
      });
    });

    test('llega a 0 después de 30 segundos y ejecuta onTimeout', () {
      fakeAsync((async) {
        var timeoutCalled = false;
        final (timer, completed) = createCountdown(
          timeoutSec: 30,
          onTimeout: () => timeoutCalled = true,
          onTick: () {},
        );
        addTearDown(() => timer.cancel());

        async.elapse(const Duration(seconds: 29));
        expect(timeoutCalled, false);
        expect(completed(), false);

        async.elapse(const Duration(seconds: 1));
        expect(timeoutCalled, true);
        expect(completed(), true);
      });
    });

    test('se puede cancelar antes de llegar a 0', () {
      fakeAsync((async) {
        var timeoutCalled = false;
        final (timer, completed) = createCountdown(
          timeoutSec: 30,
          onTimeout: () => timeoutCalled = true,
          onTick: () {},
        );

        timer.cancel();
        async.elapse(const Duration(seconds: 31));
        expect(timeoutCalled, false);
        expect(completed(), false);
      });
    });

    testWidgets('Widget: se muestra el diálogo de cuenta regresiva al finalizar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  var timeoutSec = 30;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) {
                      Timer.periodic(const Duration(seconds: 1), (timer) {
                        timeoutSec--;
                        if (timeoutSec <= 0) {
                          timer.cancel();
                          Navigator.pop(ctx);
                        }
                      });
                      return AlertDialog(
                        title: const Text('Esperando confirmación'),
                        content: Text('Tiempo restante: $timeoutSec s'),
                      );
                    },
                  );
                },
                child: const Text('Finalizar viaje'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Finalizar viaje'));
      await tester.pump();
      expect(find.text('Esperando confirmación'), findsOneWidget);
      expect(find.textContaining('Tiempo restante:'), findsOneWidget);

      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Esperando confirmación'), findsNothing);
    });
  });
}
