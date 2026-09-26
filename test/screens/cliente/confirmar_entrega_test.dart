import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/confirmar_entrega_screen.dart';
import 'package:cargaexpress/services/api/http_client.dart';

void main() {
  const btnConfirmar = Key('btn_confirmar_entrega');
  const btnRechazar = Key('btn_rechazar_entrega');
  const btnConfirmarRechazo = Key('btn_confirmar_rechazo');
  const campoMotivo = Key('campo_motivo_rechazo');

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  /// Abre el diálogo, escribe [motivo] y toca "Rechazar entrega" del diálogo.
  Future<void> rechazar(WidgetTester tester, String motivo) async {
    await tester.tap(find.byKey(btnRechazar));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(campoMotivo), motivo);
    await tester.tap(find.byKey(btnConfirmarRechazo));
    await tester.pumpAndSettle();
  }

  testWidgets('avisa que sin confirmar un moderador revisará (no se confirma solo)', (tester) async {
    await pump(tester, ConfirmarEntregaScreen(onConfirmar: () async {}));
    expect(find.textContaining('un moderador revisará'), findsOneWidget);
    expect(find.textContaining('automáticamente'), findsNothing);
  });

  testWidgets('el rechazo envía el motivo que escribió el cliente', (tester) async {
    String? motivo;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (m) async => motivo = m,
      ),
    );

    await rechazar(tester, '  Faltan dos cajas  ');
    expect(motivo, 'Faltan dos cajas');
  });

  testWidgets('el motivo es obligatorio: vacío o muy corto no se envía y se avisa', (tester) async {
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (_) async => llamadas++,
      ),
    );

    await tester.tap(find.byKey(btnRechazar));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(btnConfirmarRechazo));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el motivo del rechazo.'), findsOneWidget);
    expect(llamadas, 0);
    // El diálogo sigue abierto.
    expect(find.byKey(campoMotivo), findsOneWidget);

    await tester.enterText(find.byKey(campoMotivo), 'abc');
    await tester.tap(find.byKey(btnConfirmarRechazo));
    await tester.pumpAndSettle();
    expect(find.textContaining('al menos'), findsOneWidget);
    expect(llamadas, 0);
  });

  testWidgets('"Cancelar" cierra el diálogo sin rechazar', (tester) async {
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (_) async => llamadas++,
      ),
    );

    await tester.tap(find.byKey(btnRechazar));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(campoMotivo), 'Llegó dañada');
    await tester.tap(find.byKey(const Key('btn_cancelar_rechazo')));
    await tester.pumpAndSettle();

    expect(llamadas, 0);
    expect(find.byKey(campoMotivo), findsNothing);
    expect(find.byKey(btnRechazar), findsOneWidget);
  });

  testWidgets('rechazo exitoso: aparece "Disputa abierta" y desaparecen confirmar/rechazar', (tester) async {
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (_) async {},
      ),
    );

    await rechazar(tester, 'Faltan dos cajas');

    expect(find.text('Disputa abierta'), findsOneWidget);
    expect(find.textContaining('moderador revisará tu caso'), findsWidgets);
    expect(find.byKey(btnConfirmar), findsNothing);
    expect(find.byKey(btnRechazar), findsNothing);
    expect(find.text('Sí, confirmar entrega'), findsNothing);
    expect(find.text('¿Todo está en orden?'), findsNothing);
    expect(find.text('Volver al inicio'), findsOneWidget);
  });

  testWidgets('si el viaje ya está en disputa se muestra ese estado y no los botones', (tester) async {
    await pump(
      tester,
      ConfirmarEntregaScreen(onConfirmar: () async {}, enDisputa: true),
    );
    expect(find.text('Disputa abierta'), findsOneWidget);
    expect(find.byKey(btnConfirmar), findsNothing);
    expect(find.byKey(btnRechazar), findsNothing);
  });

  testWidgets('si rechazar falla (422) se muestra el mensaje en español y los botones vuelven', (tester) async {
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (_) async {
          llamadas++;
          throw ApiException('El viaje no está pendiente de confirmación (estado actual: disputa)', statusCode: 422);
        },
      ),
    );

    await rechazar(tester, 'Faltan dos cajas');
    expect(llamadas, 1);
    expect(find.text('El viaje no está pendiente de confirmación (estado actual: disputa)'), findsOneWidget);
    expect(find.text('Disputa abierta'), findsNothing);

    // Ambos botones vuelven a estar disponibles.
    expect(tester.widget<OutlinedButton>(find.byKey(btnRechazar)).enabled, isTrue);
    expect(tester.widget<ElevatedButton>(find.byKey(btnConfirmar)).enabled, isTrue);

    // Se puede reintentar (el aviso se retira para no tapar el botón).
    ScaffoldMessenger.of(tester.element(find.byKey(btnRechazar))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await rechazar(tester, 'Faltan dos cajas');
    expect(llamadas, 2);
  });

  testWidgets('un error inesperado al rechazar muestra un aviso genérico en español', (tester) async {
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {},
        onRechazar: (_) async => throw StateError('boom'),
      ),
    );

    await rechazar(tester, 'Faltan dos cajas');
    expect(find.textContaining('No se pudo completar la acción'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(tester.widget<OutlinedButton>(find.byKey(btnRechazar)).enabled, isTrue);
  });

  testWidgets('mientras se rechaza, ambos botones quedan deshabilitados (sin doble toque)', (tester) async {
    final completer = Completer<void>();
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async => llamadas++,
        onRechazar: (_) {
          llamadas++;
          return completer.future;
        },
      ),
    );

    await tester.tap(find.byKey(btnRechazar));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(campoMotivo), 'Faltan dos cajas');
    await tester.tap(find.byKey(btnConfirmarRechazo));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<OutlinedButton>(find.byKey(btnRechazar)).enabled, isFalse);
    expect(tester.widget<ElevatedButton>(find.byKey(btnConfirmar)).enabled, isFalse);

    // Toques repetidos no disparan otra acción.
    await tester.tap(find.byKey(btnRechazar), warnIfMissed: false);
    await tester.tap(find.byKey(btnConfirmar), warnIfMissed: false);
    await tester.pump();
    expect(llamadas, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(llamadas, 1);
    expect(find.text('Disputa abierta'), findsOneWidget);
  });

  testWidgets('doble toque en confirmar sólo llama una vez', (tester) async {
    final completer = Completer<void>();
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(onConfirmar: () {
        llamadas++;
        return completer.future;
      }),
    );

    await tester.tap(find.byKey(btnConfirmar));
    await tester.pump();
    await tester.tap(find.byKey(btnConfirmar), warnIfMissed: false);
    await tester.pump();
    expect(llamadas, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(llamadas, 1);
  });

  testWidgets('si confirmar falla, el botón vuelve a estar disponible', (tester) async {
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(
        onConfirmar: () async {
          llamadas++;
          throw Exception('sin conexión');
        },
      ),
    );

    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    expect(llamadas, 1);
    expect(find.text('Sí, confirmar entrega'), findsOneWidget);

    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    expect(llamadas, 2);
  });

  testWidgets('si el callback de confirmar termina sin navegar, se reactiva', (tester) async {
    var llamadas = 0;
    await pump(
      tester,
      ConfirmarEntregaScreen(onConfirmar: () async => llamadas++),
    );

    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, confirmar entrega'));
    await tester.pumpAndSettle();
    expect(llamadas, 2);
  });
}
