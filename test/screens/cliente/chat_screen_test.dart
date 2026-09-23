import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/chat_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

void main() {
  final emitidos = <String>[];
  setUp(() {
    emitidos.clear();
    SocketServiceClient.instance.onEmitForTest = (e, _) => emitidos.add(e);
  });
  tearDown(() => SocketServiceClient.instance.onEmitForTest = null);

  const trip = {
    '_id': 't1',
    'conductor': {'nombre': 'Carlos Pérez'},
  };

  testWidgets('enviar un mensaje usa sólo el POST (sin message:send por socket)', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.method == 'POST') return jsonResp({'ok': true});
      return jsonResp([]);
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ChatScreen(trip: trip)));
      await avanzar(tester);
      expect(find.text('No hay mensajes aún'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await avanzar(tester);
    }, log: log);

    expect(emitidos, isNot(contains('message:send')));
    final posts = log.where((r) => r.method == 'POST').toList();
    expect(posts.single.url.path, '/api/trips/t1/chat');
  });

  testWidgets('si no cargan los mensajes se avisa y se puede reintentar', (tester) async {
    pantallaAlta(tester);
    var falla = true;
    await conApiFalsa((req) => falla ? errorResp(503, 'Servicio no disponible') : jsonResp([
          {'_id': 'm1', 'mensaje': 'Voy en camino', 'isSent': false},
        ]), () async {
      await tester.pumpWidget(const MaterialApp(home: ChatScreen(trip: trip)));
      await avanzar(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No hay mensajes aún'), findsNothing);
      expect(find.text('No pudimos cargar los mensajes'), findsOneWidget);

      falla = false;
      await tester.tap(find.text('Reintentar'));
      await avanzar(tester);
      expect(find.text('Voy en camino'), findsOneWidget);
    });
  });

  testWidgets('si falla el envío se avisa al usuario', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.method == 'POST') throw http.ClientException('sin red');
      return jsonResp([]);
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ChatScreen(trip: trip)));
      await avanzar(tester);
      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await avanzar(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
