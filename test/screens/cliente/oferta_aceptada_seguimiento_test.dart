import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/socket_events.dart';
import 'package:cargaexpress/screens/cliente/confirmar_entrega_screen.dart';
import 'package:cargaexpress/screens/cliente/llegada_al_destino_screen.dart';
import 'package:cargaexpress/screens/cliente/oferta_aceptada_screen.dart';
import 'package:cargaexpress/screens/cliente/ofertas_recibidas_screen.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _viaje(String estado) => {
      '_id': 't1',
      'estado': estado,
      'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Calle 1'},
      'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Calle 2'},
      'precioEstimado': 30000,
      if (estado != 'buscando_conductor' && estado != 'pendiente')
        'conductor': {'_id': 'c1', 'nombre': 'Carlos', 'placa': 'ABC123', 'calificacion': '0.0'},
    };

const _conductorNuevo = {'id': 'c1', 'nombre': 'Carlos', 'tipoVehiculo': 'camion', 'placa': 'ABC123', 'rating': 0};

void _evento(String evento, Map<String, dynamic> data) =>
    SocketServiceClient.instance.simularEventoParaTest(evento, data);

void main() {
  late String estado;
  List<Map<String, dynamic>> ofertas = [];

  Future<void> abrirRastreo(WidgetTester tester, Future<void> Function() cuerpo) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      final p = req.url.path;
      if (p == '/api/trips/active') return jsonResp(_viaje(estado));
      if (p == '/api/trips/t1/offers') return jsonResp(ofertas);
      if (p.endsWith('/nearby-drivers')) return jsonResp({'conductores': []});
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);
      await cuerpo();
    });
  }

  setUp(() {
    estado = 'buscando_conductor';
    ofertas = [];
  });

  testWidgets('offer:accepted muestra la celebración ENCIMA del rastreo y trip:finalize_request '
      'abre la confirmación sin tocar "Ver seguimiento"', (tester) async {
    await abrirRastreo(tester, () async {
      estado = 'aceptado';
      _evento(SocketEvents.tripStatusChanged, {'id': 't1', 'estado': 'aceptado'});
      _evento('offer:accepted', {'viajeId': 't1', 'conductor': _conductorNuevo, 'estado': 'aceptado'});
      await avanzar(tester);

      expect(find.byType(OfertaAceptadaScreen), findsOneWidget);
      // El rastreo sigue vivo debajo (no fue reemplazado).
      expect(find.byType(RastreoScreen, skipOffstage: false), findsOneWidget);
      // Conductor sin calificaciones: "Nuevo", nunca "0.0".
      expect(find.text('Nuevo'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);

      estado = 'pendiente_confirmacion';
      _evento('trip:finalize_request', {'viajeId': 't1', 'estado': 'pendiente_confirmacion', 'fueraDeRango': false});
      await avanzar(tester);

      expect(find.byType(OfertaAceptadaScreen), findsNothing);
      expect(find.byType(LlegadaAlDestinoScreen), findsOneWidget);

      await tester.tap(find.text('Revisar y confirmar entrega'));
      await avanzar(tester);
      expect(find.byType(ConfirmarEntregaScreen), findsOneWidget);
    });
  });

  testWidgets('la celebración se cierra sola y queda el seguimiento del mismo rastreo', (tester) async {
    await abrirRastreo(tester, () async {
      estado = 'aceptado';
      _evento('offer:accepted', {'viajeId': 't1', 'conductor': _conductorNuevo});
      await avanzar(tester);
      expect(find.byType(OfertaAceptadaScreen), findsOneWidget);

      await avanzar(tester, duracionCelebracionOferta.inSeconds + 1.0);
      expect(find.byType(OfertaAceptadaScreen), findsNothing);
      expect(find.byType(RastreoScreen), findsOneWidget);
      expect(find.text('Conductor asignado'), findsOneWidget);
    });
  });

  testWidgets('"Ver seguimiento" vuelve al mismo rastreo (sin duplicarlo)', (tester) async {
    await abrirRastreo(tester, () async {
      estado = 'aceptado';
      _evento('offer:accepted', {'viajeId': 't1', 'conductor': _conductorNuevo});
      await avanzar(tester);

      await tester.tap(find.text('Ver seguimiento'));
      await avanzar(tester);
      expect(find.byType(OfertaAceptadaScreen), findsNothing);
      expect(find.byType(RastreoScreen, skipOffstage: false), findsOneWidget);
      expect(find.text('Conductor asignado'), findsOneWidget);

      // Un evento repetido no vuelve a abrir la celebración.
      _evento('offer:accepted', {'viajeId': 't1', 'conductor': _conductorNuevo});
      await avanzar(tester);
      expect(find.byType(OfertaAceptadaScreen), findsNothing);
    });
  });

  testWidgets('el viaje avanza (conductor en camino) y la celebración se cierra', (tester) async {
    await abrirRastreo(tester, () async {
      estado = 'aceptado';
      _evento('offer:accepted', {'viajeId': 't1', 'conductor': _conductorNuevo});
      await avanzar(tester);
      expect(find.byType(OfertaAceptadaScreen), findsOneWidget);

      _evento(SocketEvents.tripStatusChanged, {'id': 't1', 'estado': 'conductor_en_camino'});
      await avanzar(tester);
      expect(find.byType(OfertaAceptadaScreen), findsNothing);
      expect(find.text('Conductor en camino'), findsOneWidget);
    });
  });

  testWidgets('el sondeo que encuentra pendiente_confirmacion abre la confirmación', (tester) async {
    estado = 'en_curso';
    await abrirRastreo(tester, () async {
      expect(find.text('Viaje en curso'), findsOneWidget);
      estado = 'pendiente_confirmacion';
      await avanzar(tester, 11);
      expect(find.byType(LlegadaAlDestinoScreen), findsOneWidget);
    });
  });

  testWidgets('con una oferta recibida (estado pendiente) el título sigue siendo "Buscando conductor"',
      (tester) async {
    await abrirRastreo(tester, () async {
      expect(find.text('Buscando conductor'), findsWidgets);
      _evento(SocketEvents.tripStatusChanged, {'id': 't1', 'estado': 'pendiente'});
      _evento('new:offer', {'_id': 'o1', 'monto': 28000, 'conductor': _conductorNuevo});
      await avanzar(tester);
      expect(find.text('Rastreo'), findsNothing);
      expect(find.text('Buscando conductor'), findsWidgets);
      expect(find.byTooltip('Ver ofertas'), findsOneWidget);
    });
  });

  testWidgets('aceptar en la lista de ofertas vuelve al único rastreo con la celebración encima',
      (tester) async {
    ofertas = [
      {'_id': 'o1', 'monto': 28000, 'conductor': _conductorNuevo},
    ];
    await abrirRastreo(tester, () async {
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('card_ofertas')));
      await avanzar(tester, 2);
      expect(find.byType(OfertasRecibidasScreen), findsOneWidget);

      estado = 'aceptado';
      await tester.tap(find.text('Aceptar'));
      await avanzar(tester);

      expect(find.byType(OfertasRecibidasScreen), findsNothing);
      expect(find.byType(OfertaAceptadaScreen), findsOneWidget);
      expect(find.byType(RastreoScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Ver seguimiento'));
      await avanzar(tester);
      expect(find.byType(RastreoScreen), findsOneWidget);
      expect(find.text('Conductor asignado'), findsOneWidget);
    });
  });
}
