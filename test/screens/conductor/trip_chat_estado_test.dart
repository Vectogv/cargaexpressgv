import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
