import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/confirmar_entrega_screen.dart';
import 'package:cargaexpress/services/config_cliente_service.dart';

import '../helpers/fake_api.dart';

void main() {
  setUp(() => ConfigClienteService.instance.reiniciarParaTest());

  group('ReglasCliente.fromJson', () {
    test('valores configurados', () {
      final r = ReglasCliente.fromJson({'radioCierreKm': 0.5, 'confirmacionTimeoutMin': 15});
      expect(r.radioCierreKm, 0.5);
      expect(r.confirmacionTimeoutMin, 15);
      // Sin radio propio, el aviso "conductor cerca" usa el radio de cierre.
      expect(r.radioAvisoConductorCercaKm, 0.5);
    });

    test('radioConductorCercaKm opcional tiene prioridad para el aviso', () {
      final r = ReglasCliente.fromJson({'radioCierreKm': 1, 'confirmacionTimeoutMin': 10, 'radioConductorCercaKm': 2});
      expect(r.radioAvisoConductorCercaKm, 2);
    });

    test('campos ausentes o inválidos caen en 1 km / 10 min', () {
      final r = ReglasCliente.fromJson({'radioCierreKm': 'x', 'confirmacionTimeoutMin': -3});
      expect(r.radioCierreKm, 1);
      expect(r.confirmacionTimeoutMin, 10);
      expect(ReglasCliente.fromJson({}).radioAvisoConductorCercaKm, 1);
    });
  });

  group('ConfigClienteService.cargar', () {
    test('usa lo que devuelve GET /api/config/cliente y lo guarda en memoria', () async {
      final log = <http.Request>[];
      await conApiFalsa((_) => jsonResp({'radioCierreKm': 0.8, 'confirmacionTimeoutMin': 20}), () async {
        final r = await ConfigClienteService.instance.cargar();
        expect(r.radioCierreKm, 0.8);
        expect(r.confirmacionTimeoutMin, 20);
        await ConfigClienteService.instance.cargar();
      }, log: log);
      expect(log.length, 1);
      expect(log.single.method, 'GET');
      expect(log.single.url.path, '/api/config/cliente');
      expect(ConfigClienteService.instance.actual.confirmacionTimeoutMin, 20);
    });

    test('si el endpoint no existe (404) se usan 1 km / 10 min sin error', () async {
      await conApiFalsa((_) => errorResp(404, 'Cannot GET:/api/config/cliente'), () async {
        final r = await ConfigClienteService.instance.cargar();
        expect(r.radioCierreKm, 1);
        expect(r.confirmacionTimeoutMin, 10);
      });
    });

    test('sin red se conservan las últimas reglas conocidas', () async {
      await conApiFalsa((_) => jsonResp({'radioCierreKm': 0.6, 'confirmacionTimeoutMin': 12}), () async {
        await ConfigClienteService.instance.cargar();
      });
      await conApiFalsa((_) => throw http.ClientException('sin red'), () async {
        final r = await ConfigClienteService.instance.cargar(forzar: true);
        expect(r.radioCierreKm, 0.6);
        expect(r.confirmacionTimeoutMin, 12);
      });
    });
  });

  group('aviso de confirmación pendiente', () {
    testWidgets('por defecto dice 10 minutos', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvisoConfirmacionPendiente())));
      expect(find.textContaining('unos 10 minutos'), findsOneWidget);
    });

    testWidgets('usa el plazo configurado en el backend', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvisoConfirmacionPendiente())));
      ConfigClienteService.instance.reglas.value =
          ReglasCliente.fromJson({'radioCierreKm': 1, 'confirmacionTimeoutMin': 15});
      await tester.pump();
      expect(find.textContaining('unos 15 minutos'), findsOneWidget);
      expect(find.textContaining('un moderador revisará'), findsOneWidget);
    });
  });
}
