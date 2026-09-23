import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

import '../../helpers/fake_api.dart';

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
  testWidgets('con un viaje activo al abrir, el inicio abre el rastreo una vez', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      final path = req.url.path;
      if (path == '/api/trips/active') return jsonResp({'_id': 't1', 'estado': 'aceptado'});
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester, 2);
      expect(find.byType(RastreoScreen), findsOneWidget);
    });
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
