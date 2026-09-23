import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/disputa_en_revision_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _disputa(String estado) => {
      'id': '5',
      'numero': 'DSP-00005',
      'estado': estado,
      'problema': 'cliente_rechaza_cierre',
      'resultado': estado == 'resuelta' ? 'favor_cliente' : null,
    };

void main() {
  testWidgets("sólo 'resuelta' es resolución (el backend no usa 'finalizada')", (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => jsonResp(_disputa('finalizada')), () async {
      await tester.pumpWidget(const MaterialApp(home: DisputaEnRevisionScreen(disputeId: '5')));
      await avanzar(tester);
      expect(find.text('Ver resolución'), findsNothing);
      expect(find.text('Volver al inicio'), findsOneWidget);
    });
  });

  testWidgets('se actualiza sola con dispute:resolved del socket', (tester) async {
    pantallaAlta(tester);
    var estado = 'abierta';
    await conApiFalsa((_) => jsonResp(_disputa(estado)), () async {
      await tester.pumpWidget(const MaterialApp(home: DisputaEnRevisionScreen(disputeId: '5')));
      await avanzar(tester);
      expect(find.text('Volver al inicio'), findsOneWidget);

      estado = 'resuelta';
      // Otra disputa: no recarga.
      SocketServiceClient.instance.simularEventoParaTest('dispute:resolved', {'disputaId': 99});
      await avanzar(tester);
      expect(find.text('Ver resolución'), findsNothing);

      SocketServiceClient.instance.simularEventoParaTest('dispute:resolved', {'disputaId': 5, 'estado': 'resuelta'});
      await avanzar(tester);
      expect(find.text('Ver resolución'), findsOneWidget);
    });
  });

  testWidgets('dispute:updated (en revisión) también refresca el estado', (tester) async {
    pantallaAlta(tester);
    var estado = 'abierta';
    await conApiFalsa((_) => jsonResp(_disputa(estado)), () async {
      await tester.pumpWidget(const MaterialApp(home: DisputaEnRevisionScreen(disputeId: '5')));
      await avanzar(tester);
      expect(find.text('Abierta'), findsWidgets);

      estado = 'en_revision';
      SocketServiceClient.instance.simularEventoParaTest('dispute:updated', {'id': '5', 'estado': 'en_revision'});
      await avanzar(tester);
      expect(find.text('En revisión'), findsWidgets);
    });
  });

  testWidgets('deslizar hacia abajo recarga la disputa', (tester) async {
    pantallaAlta(tester);
    var estado = 'abierta';
    var consultas = 0;
    await conApiFalsa((_) {
      consultas++;
      return jsonResp(_disputa(estado));
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: DisputaEnRevisionScreen(disputeId: '5')));
      await avanzar(tester);
      estado = 'resuelta';
      await tester.fling(find.text('DSP-00005'), const Offset(0, 400), 1000);
      await avanzar(tester, 2);
      expect(consultas, 2);
      expect(find.text('Ver resolución'), findsOneWidget);
    });
  });
}
