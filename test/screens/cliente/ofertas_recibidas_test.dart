import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/ofertas_recibidas_screen.dart';

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