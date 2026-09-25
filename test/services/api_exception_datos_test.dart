import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/api/http_client.dart';

import '../helpers/fake_api.dart';

void main() {
  test('ApiException conserva los campos extra del cuerpo de error', () async {
    ApiException? error;
    await conApiFalsa(
      (_) => jsonResp({
        'error': 'No puedes cancelar: el conductor está a 0.40 km del origen (mín. 1.5 km)',
        'code': 'CONDUCTOR_CERCA',
        'distanciaKm': 0.4,
      }, 422),
      () async {
        try {
          await HttpClient.post('/api/trips/t1/cancel', body: {}, auth: true);
        } on ApiException catch (e) {
          error = e;
        }
      },
    );
    expect(error?.code, 'CONDUCTOR_CERCA');
    expect(error?.data?['distanciaKm'], 0.4);
  });

  testWidgets('CONDUCTOR_CERCA muestra el mensaje del backend (radio configurable), no "1 km" fijo',
      (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') {
        return jsonResp({
          '_id': 't1',
          'estado': 'aceptado',
          'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
          'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
          'conductor': {'nombre': 'Carlos'},
        });
      }
      if (req.url.path == '/api/trips/t1/cancel') {
        return jsonResp({
          'error': 'No puedes cancelar: el conductor está a 0.40 km del origen (mín. 1.5 km)',
          'code': 'CONDUCTOR_CERCA',
          'distanciaKm': 0.4,
        }, 422);
      }
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      await tester.ensureVisible(find.byKey(const Key('btn_cancelar_viaje')));
      await avanzar(tester);
      expect(find.text('Cancelar viaje'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_cancelar_viaje')));
      await avanzar(tester);
      await tester.tap(find.text('Cambié de opinión'));
      await tester.pump();
      await tester.tap(find.text('Sí, cancelar'));
      await avanzar(tester);

      expect(find.textContaining('0.40 km del origen (mín. 1.5 km)'), findsOneWidget);
      expect(find.textContaining('menos de 1 km'), findsNothing);
    });
  });
}
