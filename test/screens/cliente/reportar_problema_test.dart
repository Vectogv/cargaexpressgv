import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/disputa_creada_screen.dart';
import 'package:cargaexpress/screens/cliente/reportar_problema_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  // RastreoScreen pasa `Trip.toJson()`, que trae `_id` (no `id`).
  const trip = {'_id': 't1', 'estado': 'pendiente_confirmacion'};

  Future<void> enviar(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'La caja llegó rota');
    await tester.tap(find.text('Enviar reporte'));
    await avanzar(tester);
  }

  testWidgets('Reportar -> DisputaCreada con el viaje (_id) y el número real', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({'id': '5', 'numero_disputa': 'DSP-00005'}), () async {
      await tester.pumpWidget(MaterialApp(
        home: ReportarProblemaScreen(trip: trip, onSubmitted: () {}),
      ));
      await enviar(tester);
      expect(find.byType(DisputaCreadaScreen), findsOneWidget);
      expect(find.text('DSP-00005'), findsOneWidget);
    }, log: log);
    final body = jsonDecode(log.single.body) as Map<String, dynamic>;
    expect(log.single.url.path, '/api/disputes');
    expect(body['tripId'], 't1');
  });

  testWidgets('sin número de disputa no se inventa uno', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp({'id': '6', 'numero_disputa': null}), () async {
      await tester.pumpWidget(MaterialApp(
        home: ReportarProblemaScreen(trip: trip, onSubmitted: () {}),
      ));
      await enviar(tester);
      expect(find.text('DSP-00001'), findsNothing);
      expect(find.text('DIS-2024-0610-0012'), findsNothing);
      expect(find.text('#6'), findsOneWidget);
    });
  });

  testWidgets('si el backend rechaza (422) se muestra el motivo y se puede reintentar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(422, 'Solo puedes disputar viajes finalizados'), () async {
      await tester.pumpWidget(MaterialApp(
        home: ReportarProblemaScreen(trip: trip, onSubmitted: () {}),
      ));
      await enviar(tester);
      expect(find.byType(DisputaCreadaScreen), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Enviar reporte'), findsOneWidget);
    });
  });
}
