import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/calificar_conductor_screen.dart';
import 'package:cargaexpress/screens/cliente/confirmar_entrega_screen.dart';
import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/cliente/llegada_al_destino_screen.dart';
import 'package:cargaexpress/screens/cliente/nuevo_envio_screen.dart';
import 'package:cargaexpress/screens/cliente/ofertas_recibidas_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/screens/cliente/viaje_finalizado.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _viaje(String estado) => {
      '_id': 't1',
      'estado': estado,
      'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
      'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
      'precioEstimado': 30000,
      'precioFinal': 30000,
      'conductor': {'_id': 'c1', 'nombre': 'Carlos', 'placa': 'ABC123'},
    };

void main() {
  testWidgets('Inicio -> Nuevo envío', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return errorResp(404, 'Sin viaje');
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      await tester.tap(find.text('Nuevo envío').first);
      await avanzar(tester);
      expect(find.byType(NuevoEnvioScreen), findsOneWidget);
    });
  });

  testWidgets('Inicio: si falla la consulta del viaje activo se avisa con reintento', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return errorResp(500, 'Error interno');
      return jsonResp({'data': []});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      expect(find.textContaining('No pudimos verificar si tienes un viaje activo'), findsOneWidget);
    });
  });

  testWidgets('Rastreo (buscando) -> Ofertas: las ofertas existentes se ven al abrir', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      final p = req.url.path;
      if (p == '/api/trips/active') return jsonResp(_viaje('buscando_conductor'));
      if (p == '/api/trips/t1/offers') {
        return jsonResp([
          {'_id': 'o1', 'monto': 28000, 'conductor': {'nombre': 'Ana', 'tipoVehiculo': 'camion'}},
        ]);
      }
      if (p.endsWith('/nearby-drivers')) return jsonResp({'conductores': []});
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester, 2);
      await tester.tap(find.byKey(const Key('card_ofertas')));
      await avanzar(tester, 2);
      expect(find.byType(OfertasRecibidasScreen), findsOneWidget);
      expect(find.text('Ana'), findsWidgets);
    });
  });

  testWidgets('el icono de ofertas de la barra responde aunque tenga el contador encima', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      final p = req.url.path;
      if (p == '/api/trips/active') return jsonResp(_viaje('buscando_conductor'));
      if (p == '/api/trips/t1/offers') {
        return jsonResp([
          {'_id': 'o1', 'monto': 28000, 'conductor': {'nombre': 'Ana'}},
        ]);
      }
      if (p.endsWith('/nearby-drivers')) return jsonResp({'conductores': []});
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester, 2);
      await tester.tap(find.byTooltip('Ver ofertas'), warnIfMissed: false);
      await avanzar(tester, 2);
      expect(find.byType(OfertasRecibidasScreen), findsOneWidget);
    });
  });

  testWidgets('Rastreo: si no carga el viaje se avisa y se puede reintentar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(503, 'Servicio no disponible'), () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      expect(find.text('Error al cargar el viaje. Verifica tu conexión.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  testWidgets('LlegadaAlDestino -> ConfirmarEntrega -> ViajeFinalizado -> Calificar', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return jsonResp(_viaje('pendiente_confirmacion'));
      return jsonResp({'ok': true});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);

      await tester.tap(find.text('Ir a confirmación'));
      await avanzar(tester);
      expect(find.byType(LlegadaAlDestinoScreen), findsOneWidget);

      await tester.tap(find.text('Ver detalle'));
      await avanzar(tester);
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);

      await tester.tap(find.text('Sí, confirmar entrega'));
      await avanzar(tester);
      expect(find.byType(ViajeFinalizado), findsOneWidget);

      await tester.tap(find.text('Calificar al conductor'));
      await avanzar(tester);
      expect(find.byType(CalificarConductorScreen), findsOneWidget);
    }, log: log);
    expect(log.any((r) => r.method == 'POST' && r.url.path == '/api/trips/t1/confirm-close'), isTrue);
  });

  testWidgets('ConfirmarEntrega: si confirm-close falla se avisa y se puede reintentar', (tester) async {
    pantallaAlta(tester);
    var cierres = 0;
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return jsonResp(_viaje('pendiente_confirmacion'));
      if (req.url.path == '/api/trips/t1/confirm-close') {
        cierres++;
        return errorResp(409, 'El viaje cambió de estado');
      }
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      await tester.tap(find.text('Ir a confirmación'));
      await avanzar(tester);
      await tester.tap(find.text('Ver detalle'));
      await avanzar(tester);

      await tester.tap(find.text('Sí, confirmar entrega'));
      await avanzar(tester);
      expect(find.byType(ViajeFinalizado), findsNothing);
      expect(find.text('Error al confirmar: El viaje cambió de estado'), findsOneWidget);

      await tester.tap(find.text('Sí, confirmar entrega'));
      await avanzar(tester);
      expect(cierres, 2);
    });
  });
}
