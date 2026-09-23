import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/cancel_trip_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _viaje(String estado) => {
      '_id': 't1',
      'estado': estado,
      'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
      'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
      'conductor': {'_id': 'c1', 'nombre': 'Carlos'},
    };

Future<void> _conductorA300m(WidgetTester tester, String estado) async {
  pantallaAlta(tester);
  await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
  await avanzar(tester);
  // ~330 m al norte del origen: dentro del aviso (1 km), fuera de "en la zona".
  SocketServiceClient.instance.simularEventoParaTest('driver:location', {'lat': 4.603, 'lng': -74.1});
  await avanzar(tester);
}

void main() {
  testWidgets('"Cancelar viaje de todas formas" abre la cancelación real', (tester) async {
    await conApiFalsa((req) => jsonResp(_viaje('aceptado')), () async {
      await _conductorA300m(tester, 'aceptado');
      expect(find.text('El conductor ya se encuentra cerca'), findsOneWidget);

      await tester.tap(find.text('Cancelar viaje de todas formas'));
      await avanzar(tester);

      expect(find.byType(CancelTripScreen), findsOneWidget);
      expect(find.byType(RastreoScreen, skipOffstage: false), findsOneWidget);
    });
  });
}
