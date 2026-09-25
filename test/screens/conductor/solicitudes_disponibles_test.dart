import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/home_screen.dart';
import 'package:cargaexpress/services/notification_service.dart';
import 'package:cargaexpress/services/server_clock.dart';
import 'package:cargaexpress/services/socket_service_client.dart';
import 'package:cargaexpress/services/solicitudes_disponibles_service.dart';

import '../../helpers/fake_api.dart';

/// "Solicitudes disponibles" del inicio del conductor: la lista viva de
/// GET /api/trips/nearby + GET /api/drivers/offers (sondeo cada 10 s).
void main() {
  late DateTime ahora;
  late List<Map<String, dynamic>> cercanos;
  late List<Map<String, dynamic>> ofertas;

  Map<String, dynamic> viaje(String id, {int precio = 60000, String? origen}) => {
        'id': id,
        '_id': id,
        'estado': 'buscando_conductor',
        'precioEstimado': precio,
        'distancia': 2.3,
        'tiempoEstimado': 12,
        'carga': 'Cajas de archivo',
        'descripcion': 'Cajas de archivo',
        'createdAt': ahora.subtract(const Duration(seconds: 40)).toIso8601String(),
        'cliente': {'id': '2', 'nombre': 'Ana'},
        'origen': {'direccion': origen ?? 'Calle 10 #5-20', 'lat': 4.6, 'lng': -74.0},
        'destino': {'direccion': 'Carrera 7 #80-15', 'lat': 4.7, 'lng': -74.1},
      };

  Map<String, dynamic> oferta(String id, String viajeId, int segundos, {int monto = 70000}) => {
        'id': id,
        'viajeId': viajeId,
        'monto': monto,
        'estado': 'pendiente',
        'expiresAt': ahora.add(Duration(seconds: segundos)).toIso8601String(),
        'createdAt': ahora.toIso8601String(),
        'viaje': {
          'origen': {'direccion': 'Calle 10 #5-20'},
          'destino': {'direccion': 'Carrera 7 #80-15'},
          'estado': 'pendiente',
        },
      };

  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/users/profile') {
      return jsonResp({'id': 1, 'nombre': 'Luis', 'conductor': {'estadoVerificacion': 'aprobado'}});
    }
    if (p == '/api/payment/debt') return jsonResp({'estadoCuenta': 'activa', 'montoDeuda': 0});
    if (p == '/api/trips/active') return errorResp(404, 'Sin viaje');
    if (p == '/api/drivers/status') return jsonResp({'online': req.body.contains('true')});
    if (p == '/api/trips/nearby') return jsonResp(cercanos);
    if (p == '/api/drivers/offers') return jsonResp(ofertas);
    final detalle = RegExp(r'^/api/trips/(\d+)$').firstMatch(p);
    if (detalle != null) {
      final id = detalle.group(1)!;
      final v = cercanos.where((c) => c['id'] == id);
      return v.isEmpty ? errorResp(404, 'Viaje no encontrado') : jsonResp(v.first);
    }
    return jsonResp({});
  }

  setUp(() {
    ahora = DateTime.utc(2026, 9, 25, 14);
    ServerClock.ahoraLocal = () => ahora;
    cercanos = [];
    ofertas = [];
    SolicitudesDisponiblesService.instance.reiniciarParaTest();
  });

  tearDown(() {
    SolicitudesDisponiblesService.instance.reiniciarParaTest();
    ServerClock.reiniciar();
  });

  Future<void> abrir(WidgetTester tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await avanzar(tester, 3);
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await avanzar(tester, 1);
  }

  /// Cierra el aviso emergente "Nueva solicitud" con "Ignorar".
  Future<void> ignorarAviso(WidgetTester tester) async {
    expect(find.text('Nueva solicitud'), findsOneWidget);
    await tester.tap(find.text('Ignorar'));
    await avanzar(tester, 1);
    expect(find.text('Nueva solicitud'), findsNothing);
  }

  final tarjeta5 = find.byKey(const Key('solicitud_5'));

  testWidgets('ignorar el aviso no elimina la solicitud: sigue en "Solicitudes disponibles"', (tester) async {
    cercanos = [viaje('5')];
    await conApiFalsa(backend, () async {
      await abrir(tester);

      // El sondeo trae la solicitud: sale el aviso emergente.
      await ignorarAviso(tester);

      // La tarjeta sigue con precio, distancia, ruta, carga y tiempo restante.
      expect(find.text('Solicitudes disponibles'), findsOneWidget);
      expect(tarjeta5, findsOneWidget);
      expect(find.text('\$ 60.000'), findsOneWidget);
      expect(find.text('2.3 km hasta la recogida'), findsOneWidget);
      expect(find.text('12 min de viaje'), findsOneWidget);
      expect(find.text('Calle 10 #5-20'), findsOneWidget);
      expect(find.text('Carrera 7 #80-15'), findsOneWidget);
      expect(find.text('Cajas de archivo'), findsOneWidget);
      expect(find.text('14:20'), findsOneWidget); // 15 min - 40 s
      expect(find.text('Ver y ofertar'), findsOneWidget);
      expect(find.byKey(const Key('esperando_solicitudes')), findsNothing);

      // Siguientes sondeos: sigue ahí y el aviso no se repite.
      await avanzar(tester, 10);
      expect(tarjeta5, findsOneWidget);
      expect(find.text('Nueva solicitud'), findsNothing);
      await cerrar(tester);
    });
  });

  testWidgets('la lista se actualiza por sondeo: aparece cuando el backend la devuelve y desaparece cuando deja de hacerlo', (tester) async {
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.byKey(const Key('esperando_solicitudes')), findsOneWidget);
      expect(tarjeta5, findsNothing);

      cercanos = [viaje('5')];
      await avanzar(tester, 10);
      await ignorarAviso(tester);
      expect(tarjeta5, findsOneWidget);
      expect(find.byKey(const Key('esperando_solicitudes')), findsNothing);

      // Otro conductor la tomó / se canceló: el backend ya no la devuelve.
      cercanos = [];
      await avanzar(tester, 10);
      expect(tarjeta5, findsNothing);
      expect(find.byKey(const Key('esperando_solicitudes')), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('el aviso trip:nearby del socket entra a la lista al instante y trip:accepted la quita', (tester) async {
    await conApiFalsa(backend, () async {
      await abrir(tester);

      // Sondeo aún sin el viaje: el socket lo anuncia con el payload mínimo.
      NotificationService.instance.simularEventoParaTest('trip:nearby', {
        'tripId': '7', 'id': '7', '_id': '7', 'origen': 'Avenida 30 #4-10', 'precioEstimado': 48000, 'type': 'new_trip',
      });
      await avanzar(tester, 1);
      await ignorarAviso(tester);
      expect(find.byKey(const Key('solicitud_7')), findsOneWidget);
      expect(find.text('\$ 48.000'), findsOneWidget);
      expect(find.text('Avenida 30 #4-10'), findsOneWidget);

      // El sondeo ya lo trae completo.
      cercanos = [viaje('7', precio: 48000, origen: 'Avenida 30 #4-10')];
      await avanzar(tester, 10);
      expect(find.byKey(const Key('solicitud_7')), findsOneWidget);
      expect(find.text('Carrera 7 #80-15'), findsOneWidget);

      // Lo ganó otro conductor.
      cercanos = [];
      NotificationService.instance.simularEventoParaTest('trip:accepted', {'tripId': '7', 'conductorId': 99});
      await avanzar(tester, 1);
      expect(find.byKey(const Key('solicitud_7')), findsNothing);
      await cerrar(tester);
    });
  });

  testWidgets('con oferta pendiente muestra "Oferta enviada" y, si el cliente la rechaza, deja ofertar de nuevo', (tester) async {
    cercanos = [viaje('5')];
    ofertas = [oferta('31', '5', 25)];
    await conApiFalsa(backend, () async {
      await abrir(tester);

      // Con oferta propia no hay aviso emergente ni invitación a ofertar.
      expect(find.text('Nueva solicitud'), findsNothing);
      expect(tarjeta5, findsOneWidget);
      expect(find.byKey(const Key('oferta_enviada')), findsOneWidget);
      expect(find.text('Oferta enviada · \$ 70.000 · vence en 0:25'), findsOneWidget);
      expect(find.text('Ver mi oferta'), findsOneWidget);
      expect(find.text('Ver y ofertar'), findsNothing);

      // El cliente la rechaza: el backend deja ofertar de nuevo
      // (offer_controller.store sólo bloquea si hay otra oferta pendiente).
      ofertas = [];
      SocketServiceClient.instance.simularEventoParaTest('offer:rejected', {'viajeId': '5', 'ofertaId': '31'});
      await avanzar(tester, 1);
      expect(tarjeta5, findsOneWidget);
      expect(find.byKey(const Key('oferta_enviada')), findsNothing);
      expect(find.byKey(const Key('oferta_rechazada')), findsOneWidget);
      expect(find.text('Ver y ofertar'), findsOneWidget);
      expect(find.text('Nueva solicitud'), findsNothing); // ya la conocía

      // El siguiente sondeo no la quita (el backend la sigue devolviendo).
      await avanzar(tester, 10);
      expect(tarjeta5, findsOneWidget);
      expect(find.byKey(const Key('oferta_rechazada')), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('al desconectarse la lista se vacía y se invita a conectarse', (tester) async {
    cercanos = [viaje('5')];
    await conApiFalsa(backend, () async {
      await abrir(tester);
      await ignorarAviso(tester);
      expect(tarjeta5, findsOneWidget);

      await tester.tap(find.byType(Switch));
      await avanzar(tester, 1);
      expect(tarjeta5, findsNothing);
      expect(find.text('Estás desconectado'), findsOneWidget);
      expect(SolicitudesDisponiblesService.instance.activo, isFalse);
      await cerrar(tester);
    });
  });
}
