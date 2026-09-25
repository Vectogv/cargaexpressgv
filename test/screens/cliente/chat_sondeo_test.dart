import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/chat_screen.dart';

import '../../helpers/fake_api.dart';

/// En segundo plano el sistema corta el socket y la app lo cree conectado:
/// el mensaje nuevo debe aparecer por el sondeo, sin salir y volver a entrar.
void main() {
  testWidgets('un mensaje nuevo del conductor aparece solo, sin socket', (tester) async {
    pantallaAlta(tester);
    var mensajes = <Map<String, dynamic>>[
      {'id': 1, 'tripId': '5', 'senderId': '40', 'isSent': false, 'mensaje': 'Voy en camino', 'createdAt': '2026-09-25T20:00:00.000Z'},
    ];
    await conApiFalsa((req) {
      if (req.method == 'GET' && req.url.path == '/api/trips/5/chat') return jsonResp(mensajes);
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(
        home: ChatScreen(trip: {'_id': '5', 'estado': 'conductor_llegada', 'conductor': {'nombre': 'Carlos'}}),
      ));
      await avanzar(tester);
      expect(find.text('Voy en camino'), findsOneWidget);
      expect(find.text('Ya llegué, estoy afuera'), findsNothing);

      mensajes = [
        ...mensajes,
        {'id': 2, 'tripId': '5', 'senderId': '40', 'isSent': false, 'mensaje': 'Ya llegué, estoy afuera', 'createdAt': '2026-09-25T20:01:00.000Z'},
      ];
      await tester.pump(const Duration(seconds: 5));
      await avanzar(tester);
      expect(find.text('Ya llegué, estoy afuera'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await avanzar(tester);
    });
  });
}
