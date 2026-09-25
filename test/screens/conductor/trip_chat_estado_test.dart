import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/conductor/trip_chat_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  Future<void> abrir(WidgetTester tester, String estado) async {
    await tester.pumpWidget(MaterialApp(
      home: TripChatScreen(trip: {'id': 't1', 'estado': estado}),
    ));
    await avanzar(tester);
  }

  testWidgets('durante un SOS el conductor puede chatear', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => jsonResp([]), () async {
      await abrir(tester, 'sos');
      expect(find.text('Chat no disponible'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  testWidgets('abierto desde el viaje (Trip.toJson, con _id) lee y envía al viaje correcto', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    final trip = Trip.fromJson({
      'id': '5',
      'estado': 'en_curso',
      'origen': {'direccion': 'Parque Caldas', 'lat': 2.44188, 'lng': -76.60631},
      'destino': {'direccion': 'Campanario', 'lat': 2.46129, 'lng': -76.5915},
      'cliente': {'id': 2, 'nombre': 'Ana Pérez'},
    });
    await conApiFalsa((req) {
      if (req.method == 'GET' && req.url.path == '/api/trips/5/chat') {
        return jsonResp([
          {'id': 1, 'tripId': '5', 'senderId': '2', 'isSent': false, 'mensaje': 'Ya bajo', 'createdAt': '2026-09-25T14:05:00.000Z'},
        ]);
      }
      return jsonResp({'id': 2, 'tripId': '5', 'mensaje': 'Te espero afuera'});
    }, () async {
      await tester.pumpWidget(MaterialApp(home: TripChatScreen(trip: trip.toJson())));
      await avanzar(tester);
      expect(find.text('Viaje #5'), findsOneWidget);
      expect(find.text('Ya bajo'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Te espero afuera');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await avanzar(tester);
      expect(find.text('Te espero afuera'), findsOneWidget);
    }, log: log);

    expect(log.where((r) => r.url.path.contains('null')), isEmpty);
    final post = log.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/trips/5/chat');
    expect(post.body, contains('Te espero afuera'));
  });

  for (final estado in ['entregado', 'esperando_confirmacion']) {
    testWidgets('en $estado el chat no está disponible (el backend lo rechaza)', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((req) => jsonResp([]), () async {
        await abrir(tester, estado);
        expect(find.text('Chat no disponible'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      });
    });
  }
}
