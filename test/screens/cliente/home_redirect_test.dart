import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/confirmar_entrega_screen.dart';
import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/screens/cliente/viaje_finalizado.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _viaje(String estado) => {
      '_id': 't1',
      'estado': estado,
      'origen': {'direccion': 'Calle 1'},
      'destino': {'direccion': 'Calle 2'},
      'precioFinal': 30000,
      'conductor': {'_id': 'c1', 'nombre': 'Carlos', 'placa': 'ABC123'},
    };

class _PilaObserver extends NavigatorObserver {
  final List<Route<dynamic>> pila = [];
  @override
  void didPush(Route route, Route? previousRoute) => pila.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => pila.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => pila.remove(route);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final i = pila.indexOf(oldRoute!);
    if (i >= 0) pila[i] = newRoute!;
  }
}

void main() {
  testWidgets('con un viaje activo al abrir, el inicio lo muestra en su tarjeta y "Ver detalle" abre el rastreo',
      (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      final path = req.url.path;
      if (path == '/api/trips/active') return jsonResp(_viaje('aceptado'));
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester, 2);
      expect(find.byType(RastreoScreen), findsNothing);
      expect(find.byKey(const Key('card_viaje_activo')), findsOneWidget);

      await tester.tap(find.text('Ver detalle ›'));
      await avanzar(tester);
      expect(find.byType(RastreoScreen), findsOneWidget);
    });
  });

  testWidgets('confirmar la entrega desde el inicio: confirm-close y ViajeFinalizado', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return jsonResp(_viaje('pendiente_confirmacion'));
      return jsonResp({'ok': true});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('btn_confirmar_entrega_inicio')));
      await avanzar(tester);
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);

      await tester.tap(find.text('Sí, confirmar entrega'));
      await avanzar(tester);
      expect(find.byType(ViajeFinalizado), findsOneWidget);
    }, log: log);
    final cierre = log.singleWhere((r) => r.url.path == '/api/trips/t1/confirm-close');
    expect(cierre.body, contains('"confirmar":true'));
  });

  testWidgets('"Hay un problema" desde el inicio abre el motivo y rechaza; al volver el inicio muestra la disputa',
      (tester) async {
    pantallaAlta(tester);
    var estado = 'pendiente_confirmacion';
    final log = <http.Request>[];
    await conApiFalsa((req) {
      final p = req.url.path;
      if (p == '/api/trips/active') return jsonResp(_viaje(estado));
      if (p == '/api/trips/t1/confirm-close') {
        estado = 'disputa';
        return jsonResp({'id': 't1', 'estado': 'disputa', 'disputaId': 9});
      }
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('btn_problema_entrega')));
      await avanzar(tester);
      expect(find.byKey(const Key('campo_motivo_rechazo')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('campo_motivo_rechazo')), 'Faltan cajas');
      await tester.tap(find.byKey(const Key('btn_confirmar_rechazo')));
      await avanzar(tester, 2);
      expect(find.text('Volver al inicio'), findsOneWidget);

      // El SnackBar "Rechazaste la entrega" tapa el botón hasta que se va.
      await tester.pump(const Duration(seconds: 5));
      await avanzar(tester);
      await tester.tap(find.text('Volver al inicio'));
      await avanzar(tester);
      expect(find.byType(ClienteHomeScreen), findsOneWidget);
      expect(find.text('Ver estado del caso'), findsOneWidget);
    }, log: log);
    final cierre = log.singleWhere((r) => r.url.path == '/api/trips/t1/confirm-close');
    expect(cierre.body, contains('"confirmar":false'));
    expect(cierre.body, contains('Faltan cajas'));
  });

  testWidgets('crear un envío y recargar el inicio no abre un segundo rastreo', (tester) async {
    pantallaAlta(tester);
    Map<String, dynamic>? activo;
    await conApiFalsa((req) {
      final path = req.url.path;
      if (path == '/api/trips/active') {
        return activo == null ? errorResp(404, 'Sin viaje activo') : jsonResp(activo);
      }
      if (path == '/api/trips/history') return jsonResp({'data': []});
      if (path.endsWith('/offers')) return jsonResp([]);
      if (path.endsWith('/nearby-drivers')) return jsonResp({'conductores': []});
      return jsonResp({'data': []});
    }, () async {
      final nav = GlobalKey<NavigatorState>();
      final obs = _PilaObserver();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [obs],
        home: const ClienteHomeScreen(),
      ));
      await avanzar(tester);

      // "Nuevo envío" desde el inicio.
      await tester.tap(find.text('Nuevo envío').first);
      await avanzar(tester);

      // NuevoEnvio crea el viaje y se reemplaza por RastreoScreen.
      activo = {'_id': 't1', 'estado': 'buscando'};
      nav.currentState!.pushReplacement(MaterialPageRoute(builder: (_) => const RastreoScreen()));
      await avanzar(tester, 2);

      final rastreos = obs.pila
          .whereType<MaterialPageRoute>()
          .where((r) => r.builder(nav.currentContext!) is RastreoScreen)
          .length;
      expect(rastreos, 1);
      expect(find.byType(RastreoScreen), findsOneWidget);
    });
  });
}
