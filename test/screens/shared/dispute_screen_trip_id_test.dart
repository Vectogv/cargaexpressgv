import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/models/trip.dart';
import 'package:cargaexpress/screens/shared/dispute_screen.dart';

import '../../helpers/fake_api.dart';

/// "Reportar" en el viaje del conductor abre la disputa con `Trip.toJson()`,
/// que trae el id como `_id`: la disputa debe ir al viaje real, no a null.
void main() {
  testWidgets('la disputa abierta con Trip.toJson() se envía con el id del viaje', (tester) async {
    pantallaAlta(tester);
    final trip = Trip.fromJson({
      'id': '5',
      'estado': 'en_curso',
      'origen': {'direccion': 'Parque Caldas', 'lat': 2.44188, 'lng': -76.60631},
      'destino': {'direccion': 'Campanario', 'lat': 2.46129, 'lng': -76.5915},
      'cliente': {'id': 2, 'nombre': 'Ana Pérez'},
    });
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp({'id': 9, 'numero': 'DSP-00009'}), () async {
      await tester.pumpWidget(MaterialApp(home: DisputeScreen(trip: trip.toJson(), role: 'conductor')));
      await avanzar(tester);
      expect(find.text('Viaje #5'), findsOneWidget);

      await tester.tap(find.text('Cliente ausente'));
      await tester.enterText(find.byType(TextField), 'No salió a recibir la carga');
      await tester.ensureVisible(find.text('Enviar disputa'));
      await tester.tap(find.text('Enviar disputa'));
      await avanzar(tester);
    }, log: log);

    final post = log.singleWhere((r) => r.method == 'POST' && r.url.path == '/api/disputes');
    expect(post.body, contains('"tripId":"5"'));
  });
}
