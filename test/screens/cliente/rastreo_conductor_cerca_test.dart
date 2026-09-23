import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/cancel_trip_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/config_cliente_service.dart';
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
  setUp(() => ConfigClienteService.instance.reiniciarParaTest());

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

  testWidgets('el aviso también sale con el conductor en camino (el backend penaliza igual)',
      (tester) async {
    await conApiFalsa((req) => jsonResp(_viaje('conductor_en_camino')), () async {
      await _conductorA300m(tester, 'conductor_en_camino');
      expect(find.text('El conductor ya se encuentra cerca'), findsOneWidget);
    });
  });

  testWidgets('radio configurado en el backend (0.2 km): a 330 m no se avisa', (tester) async {
    await conApiFalsa((req) {
      if (req.url.path == '/api/config/cliente') {
        return jsonResp({'radioCierreKm': 0.2, 'confirmacionTimeoutMin': 10});
      }
      return jsonResp(_viaje('aceptado'));
    }, () async {
      await _conductorA300m(tester, 'aceptado');
      expect(ConfigClienteService.instance.actual.radioCierreKm, 0.2);
      expect(find.text('El conductor ya se encuentra cerca'), findsNothing);
    });
  });

  testWidgets('si /api/config/cliente no existe se avisa a 1 km', (tester) async {
    await conApiFalsa((req) {
      if (req.url.path == '/api/config/cliente') return errorResp(404, 'Cannot GET:/api/config/cliente');
      return jsonResp(_viaje('aceptado'));
    }, () async {
      await _conductorA300m(tester, 'aceptado');
      expect(find.text('El conductor ya se encuentra cerca'), findsOneWidget);
    });
  });
}