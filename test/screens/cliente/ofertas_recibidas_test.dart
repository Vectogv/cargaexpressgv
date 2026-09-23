import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/ofertas_recibidas_screen.dart';
import 'package:cargaexpress/services/api/http_client.dart' show ApiException;

void main() {
  testWidgets('aceptar oferta usa el _id cuando el backend envía _id',
      (tester) async {
    String? acceptedId;
    String? rejectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: OfertasRecibidasScreen(
          ofertas: [
            {
              '_id': 'offer_abc_123',
              'monto': 250,
              'conductor': {
                '_id': 'conductor_1',
                'nombre': 'Carlos',
                'tipoVehiculo': 'camioneta',
                'calificacion': 4.5,
              },
            },
          ],
          trip: {'precioEstimado': 200},
          onAccept: (offerId) async {
            acceptedId = offerId;
          },
          onReject: (offerId) async {
            rejectedId = offerId;
          },
        ),
      ),
    );

    expect(find.text('Ofertas recibidas (1)'), findsOneWidget);

    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(acceptedId, 'offer_abc_123');
    expect(rejectedId, isNull);
  });

  Map<String, dynamic> oferta(String id, {String? expiresAt}) => {
        '_id': id,
        'monto': 250,
        'conductor': {'nombre': 'Carlos', 'tipoVehiculo': 'camion'},
        if (expiresAt != null) 'expiresAt': expiresAt,
      };

  testWidgets('aceptar con 400 (el viaje ya no acepta ofertas) vuelve al rastreo con el aviso',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('Rastreo'))));
    nav.currentState!.push(MaterialPageRoute(
      builder: (_) => OfertasRecibidasScreen(
        ofertas: [oferta('o1')],
        trip: const {},
        onAccept: (_) async => throw ApiException('El viaje ya no acepta ofertas', statusCode: 400),
        onReject: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.byType(OfertasRecibidasScreen), findsNothing);
    expect(find.text('Rastreo'), findsOneWidget);
    expect(find.text('El viaje ya no acepta ofertas'), findsOneWidget);
  });

  testWidgets('rechazar con 404 (ya procesada) quita la oferta de la lista', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OfertasRecibidasScreen(
        ofertas: [oferta('o1'), oferta('o2')],
        trip: const {},
        onAccept: (_) async {},
        onReject: (_) async => throw ApiException('Oferta no encontrada o ya procesada', statusCode: 404),
      ),
    ));
    expect(find.text('Ofertas recibidas (2)'), findsOneWidget);
    await tester.tap(find.text('Rechazar').first);
    await tester.pumpAndSettle();
    expect(find.text('Ofertas recibidas (1)'), findsOneWidget);
  });

  testWidgets('una oferta expirada se puede descartar pero no aceptar', (tester) async {
    String? descartada;
    await tester.pumpWidget(MaterialApp(
      home: OfertasRecibidasScreen(
        ofertas: [oferta('o1', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String())],
        trip: const {},
        onAccept: (_) async {},
        onReject: (id) async => descartada = id,
      ),
    ));
    expect(find.text('Oferta expirada'), findsOneWidget);
    final aceptar = tester.widget<ElevatedButton>(find.ancestor(of: find.text('Aceptar'), matching: find.byType(ElevatedButton)));
    expect(aceptar.onPressed, isNull);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(descartada, 'o1');
  });

  testWidgets('rechazar oferta usa el _id cuando el backend envía _id',
      (tester) async {
    String? rejectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: OfertasRecibidasScreen(
          ofertas: [
            {
              '_id': 'offer_xyz_789',
              'monto': 300,
              'conductor': {
                '_id': 'conductor_2',
                'nombre': 'María',
                'tipoVehiculo': 'camion',
                'calificacion': 4.8,
              },
            },
          ],
          trip: {'precioEstimado': 200},
          onAccept: (offerId) async {},
          onReject: (offerId) async {
            rejectedId = offerId;
          },
        ),
      ),
    );

    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    expect(rejectedId, 'offer_xyz_789');
    expect(find.text('Ofertas recibidas (0)'), findsOneWidget);
  });
}