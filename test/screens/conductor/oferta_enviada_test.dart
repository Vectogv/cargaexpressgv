import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/oferta_enviada_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

void main() {
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const OfertaEnviadaScreen(montoOferta: '\$60.000', tripId: '9'),
            )),
            child: const Text('Ofertar'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ofertar'));
    await avanzar(tester);
    expect(find.text('Oferta enviada'), findsOneWidget);
  }

  testWidgets('offer:expired de este viaje: avisa y vuelve para poder ofertar de nuevo', (tester) async {
    await conApiFalsa((_) => jsonResp({}), () async {
      await abrir(tester);
      SocketServiceClient.instance.simularEventoParaTest('offer:expired', {'viajeId': '9', 'ofertaId': '31'});
      await avanzar(tester);
      expect(find.text('Oferta enviada'), findsNothing);
      expect(find.text('Ofertar'), findsOneWidget);
      expect(find.textContaining('Tu oferta expiró'), findsOneWidget);
    });
  });

  testWidgets('offer:rejected sale aunque la pantalla esté quieta', (tester) async {
    await conApiFalsa((_) => jsonResp({}), () async {
      await abrir(tester);
      SocketServiceClient.instance.simularEventoParaTest('offer:rejected', {'viajeId': '9'});
      await avanzar(tester);
      expect(find.text('Oferta enviada'), findsNothing);
      expect(find.text('El cliente rechazó tu oferta'), findsOneWidget);
    });
  });

  testWidgets('offer:expired de otro viaje no afecta', (tester) async {
    await conApiFalsa((_) => jsonResp({}), () async {
      await abrir(tester);
      SocketServiceClient.instance.simularEventoParaTest('offer:expired', {'viajeId': '77', 'ofertaId': '1'});
      await avanzar(tester);
      expect(find.text('Oferta enviada'), findsOneWidget);
    });
  });
}
