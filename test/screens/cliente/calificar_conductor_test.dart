import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/calificar_conductor_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  Widget pantalla(VoidCallback onSubmitted) => CalificarConductorScreen(
        conductor: const {'nombre': 'Carlos', 'rating': 4.5},
        tripId: 't1',
        onSubmitted: onSubmitted,
      );

  testWidgets('el comentario se limita a 250 caracteres con contador', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(MaterialApp(home: pantalla(() {})));
    final campo = find.byType(TextField);
    await tester.enterText(campo, 'x' * 300);
    await tester.pump();
    expect(tester.widget<TextField>(campo).controller!.text.length, 250);
    expect(find.text('250/250'), findsOneWidget);
  });

  testWidgets('sin estrellas no se envía la calificación', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    var enviados = 0;
    await conApiFalsa((_) => jsonResp({'ok': true}), () async {
      await tester.pumpWidget(MaterialApp(home: pantalla(() => enviados++)));
      await tester.tap(find.text('Enviar calificación'));
      await avanzar(tester);
    }, log: log);
    expect(log, isEmpty);
    expect(enviados, 0);
  });

  testWidgets('al enviar, la navegación la hace sólo onSubmitted (una vez)', (tester) async {
    pantallaAlta(tester);
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({'ok': true}), () async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('Inicio')),
      ));
      var enviados = 0;
      // Inicio -> ViajeFinalizado (simulado) -> Calificar
      nav.currentState!.push(MaterialPageRoute(builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => pantalla(() {
                  enviados++;
                  Navigator.popUntil(ctx, (r) => r.isFirst);
                }),
              )),
              child: const Text('Calificar'),
            ),
          )));
      await avanzar(tester);
      await tester.tap(find.text('Calificar'));
      await avanzar(tester);

      await tester.tap(find.byIcon(Icons.star_border).at(4));
      await tester.pump();
      await tester.tap(find.text('Enviar calificación'));
      await avanzar(tester);

      expect(tester.takeException(), isNull);
      expect(enviados, 1);
      expect(find.text('Inicio'), findsOneWidget);
    }, log: log);
    expect(log.single.url.path, '/api/trips/t1/rate');
  });

  testWidgets('si el backend falla se muestra el error y se puede reintentar', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((_) => errorResp(500, 'Falla temporal'), () async {
      await tester.pumpWidget(MaterialApp(home: pantalla(() {})));
      await tester.tap(find.byIcon(Icons.star_border).at(2));
      await tester.pump();
      await tester.tap(find.text('Enviar calificación'));
      await avanzar(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Enviar calificación'), findsOneWidget);
    });
  });
}
