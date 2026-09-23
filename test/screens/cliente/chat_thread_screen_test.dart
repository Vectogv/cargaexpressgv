import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/chat_thread_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  Widget pantalla({
    required Future<List<Map<String, dynamic>>> Function() fetch,
    Future<Map<String, dynamic>> Function(String)? enviar,
  }) =>
      MaterialApp(
        home: ChatThreadScreen(
          titulo: 'Soporte',
          subtitulo: 'En línea',
          threadId: 'c1',
          idField: 'conversacionId',
          fetchMensajes: fetch,
          enviarMensaje: enviar ?? (_) async => {'id': 'm9'},
          mensajesSocket: const Stream.empty(),
        ),
      );

  testWidgets('abre y muestra los mensajes', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(pantalla(fetch: () async => [
          {'id': 'm1', 'mensaje': 'Hola, ¿en qué te ayudamos?', 'remitente': {'id': 'soporte'}},
        ]));
    await avanzar(tester);
    expect(find.text('Hola, ¿en qué te ayudamos?'), findsOneWidget);
  });

  testWidgets('si no cargan los mensajes se avisa y se puede reintentar', (tester) async {
    pantallaAlta(tester);
    var falla = true;
    await tester.pumpWidget(pantalla(fetch: () async {
      if (falla) throw Exception('Sin conexión a internet');
      return [
        {'id': 'm1', 'mensaje': 'Listo', 'remitente': {'id': 'soporte'}},
      ];
    }));
    await avanzar(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No pudimos cargar los mensajes'), findsOneWidget);

    falla = false;
    await tester.tap(find.text('Reintentar'));
    await avanzar(tester);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('si falla el envío se avisa al usuario', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(pantalla(
      fetch: () async => [],
      enviar: (_) async => throw Exception('El servidor tardó demasiado'),
    ));
    await avanzar(tester);
    await tester.enterText(find.byType(TextField), 'Ayuda');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await avanzar(tester);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
