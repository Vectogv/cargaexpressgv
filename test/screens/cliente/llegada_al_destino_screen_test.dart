import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/llegada_al_destino_screen.dart';
import 'package:cargaexpress/widgets/media_image.dart';

void main() {
  Future<void> pumpPantalla(WidgetTester tester, Map<String, dynamic> trip) async {
    await tester.pumpWidget(MaterialApp(
      home: LlegadaAlDestinoScreen(
        conductor: const {'nombre': 'Juan Pérez'},
        trip: trip,
        onVerDetalle: () {},
      ),
    ));
  }

  testWidgets('con fotoEntrega muestra MediaImage y no el estado vacío', (tester) async {
    await pumpPantalla(tester, {
      'fotoEntrega': '/storage/uploads/evidencia.jpg',
      'destino': const {'lat': 10.0, 'lng': -84.0},
    });

    expect(find.byType(MediaImage), findsOneWidget);
    expect(find.text('El conductor no adjuntó foto'), findsNothing);
  });

  testWidgets('sin fotoEntrega muestra el estado vacío honesto, sin dibujo falso', (tester) async {
    await pumpPantalla(tester, {
      'destino': const {'lat': 10.0, 'lng': -84.0},
    });

    expect(find.byType(MediaImage), findsNothing);
    expect(find.text('El conductor no adjuntó foto'), findsOneWidget);
    expect(find.byIcon(Icons.no_photography_outlined), findsOneWidget);
  });
}
