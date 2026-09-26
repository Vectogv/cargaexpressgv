import 'dart:io' show HttpDate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/ofertas_recibidas_screen.dart';
import 'package:cargaexpress/screens/conductor/conductor_trip_detail_screen.dart';
import 'package:cargaexpress/services/server_clock.dart';

import '../../helpers/fake_api.dart';

/// Las cuentas regresivas de solicitudes y ofertas usan la hora del servidor
/// ([ServerClock]), no la del teléfono: con el reloj del teléfono 5 min
/// adelantado el tiempo restante sigue siendo el que dicta el backend.
void main() {
  late DateTime servidor;

  setUp(() {
    servidor = DateTime.utc(2026, 9, 25, 14, 0, 0);
    // Teléfono 5 minutos adelantado; la cabecera Date del backend lo corrige.
    ServerClock.ahoraLocal = () => servidor.add(const Duration(minutes: 5));
    ServerClock.registrarFecha(HttpDate.format(servidor));
    expect(ServerClock.desfase, const Duration(minutes: -5));
  });

  tearDown(ServerClock.reiniciar);

  testWidgets('detalle de la solicitud: la cuenta regresiva parte de la hora del servidor', (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final trip = {
      'id': '5',
      'estado': 'buscando_conductor',
      'createdAt': servidor.subtract(const Duration(seconds: 40)).toIso8601String(),
      'origen': {'direccion': 'Calle 10 #5-20', 'lat': 4.6, 'lng': -74.0},
      'destino': {'direccion': 'Carrera 7 #80-15', 'lat': 4.7, 'lng': -74.1},
      'precioEstimado': 60000,
    };
    await conApiFalsa((_) => jsonResp({}), () async {
      await tester.pumpWidget(MaterialApp(home: ConductorTripDetailScreen(trip: trip)));
      await tester.pump();
      // 15 min de búsqueda − 40 s = 14:20 (con el reloj del teléfono serían 9:20).
      expect(find.text('14:20'), findsOneWidget);
      expect(find.text('09:20'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('14:18'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('ofertas recibidas (cliente): "Expira en" se calcula con la hora del servidor', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OfertasRecibidasScreen(
        ofertas: [
          {
            '_id': 'o1',
            'monto': 250,
            'conductor': {'nombre': 'Carlos', 'tipoVehiculo': 'camion'},
            'expiresAt': servidor.add(const Duration(seconds: 20)).toIso8601String(),
          },
        ],
        trip: const {'precioEstimado': 200},
        onAccept: (_) async {},
        onReject: (_) async {},
      ),
    ));
    await tester.pump();
    // Con el reloj del teléfono (5 min adelantado) ya estaría "expirada".
    expect(find.text('Expira en 20 s'), findsOneWidget);
    expect(find.text('Oferta expirada'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
