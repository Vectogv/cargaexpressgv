import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/hacer_oferta_screen.dart';
import 'package:cargaexpress/screens/conductor/oferta_aceptada_screen.dart';
import 'package:cargaexpress/screens/conductor/oferta_enviada_screen.dart';
import 'package:cargaexpress/screens/conductor/offers_screen.dart';
import 'package:cargaexpress/services/server_clock.dart';
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

  group('vencimiento con expiresAt', () {
    late DateTime ahora;
    setUp(() {
      ahora = DateTime.utc(2026, 9, 23, 15);
      ServerClock.ahoraLocal = () => ahora;
    });
    tearDown(ServerClock.reiniciar);

    Future<void> pasar(WidgetTester tester, int segundos) async {
      for (var i = 0; i < segundos; i++) {
        ahora = ahora.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    Future<void> abrirConVencimiento(WidgetTester tester, DateTime venceEn) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => OfertaEnviadaScreen(montoOferta: '\$60.000', tripId: '9', venceEn: venceEn),
              )),
              child: const Text('Ofertar'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Ofertar'));
      await avanzar(tester);
    }

    testWidgets('cuenta regresiva desde expiresAt y al vencer sin respuesta vuelve', (tester) async {
      await conApiFalsa((req) => jsonResp({'id': '9', 'estado': 'buscando'}), () async {
        await abrirConVencimiento(tester, ahora.add(const Duration(seconds: 20)));
        expect(find.text('Vence en 0:20'), findsOneWidget);
        await pasar(tester, 5);
        expect(find.text('Vence en 0:15'), findsOneWidget);
        await pasar(tester, 20);
        await avanzar(tester);
        expect(find.text('Oferta enviada'), findsNothing);
        expect(find.textContaining('Tu oferta expiró'), findsOneWidget);
      });
    });

    testWidgets('si al vencer el viaje ya fue aceptado, va al viaje', (tester) async {
      await conApiFalsa((req) => jsonResp({'id': '9', 'estado': 'aceptado', 'cliente': {'nombre': 'Ana'}}), () async {
        await abrirConVencimiento(tester, ahora.add(const Duration(seconds: 3)));
        await pasar(tester, 8);
        await avanzar(tester, 2);
        expect(find.byType(OfertaAceptadaScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await avanzar(tester);
      });
    });

    testWidgets('HacerOferta devuelve el vencimiento según expiresAt - createdAt del servidor', (tester) async {
      pantallaAlta(tester);
      OfertaCreada? creada;
      // El reloj del teléfono va 1 minuto atrasado respecto al servidor.
      final servidor = ahora.add(const Duration(minutes: 1));
      await conApiFalsa((req) => jsonResp({
            'id': '31',
            'viajeId': '9',
            'monto': 60000,
            'estado': 'pendiente',
            'createdAt': servidor.toIso8601String(),
            'expiresAt': servidor.add(const Duration(seconds: 28)).toIso8601String(),
          }, 201), () async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  creada = await Navigator.push<OfertaCreada>(context, MaterialPageRoute(
                    builder: (_) => const HacerOfertaScreen(tripId: '9', ofertaInicial: 60000),
                  ));
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Abrir'));
        await avanzar(tester);
        await tester.tap(find.text('Enviar oferta'));
        await avanzar(tester);
      });
      expect(creada, isNotNull);
      expect(creada!.monto, '\$60.000');
      expect(creada!.venceEn!.difference(ServerClock.ahora()), const Duration(seconds: 28));
    });
  });

  testWidgets('Ir a mis ofertas abre la lista de ofertas', (tester) async {
    await conApiFalsa((req) {
      if (req.url.path == '/api/drivers/offers') return jsonResp([]);
      return jsonResp({});
    }, () async {
      await abrir(tester);
      await tester.tap(find.text('Ir a mis ofertas'));
      await avanzar(tester);
      expect(find.byType(OffersScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await avanzar(tester);
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
