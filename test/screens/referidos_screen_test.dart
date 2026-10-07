import 'package:cargaexpress/screens/conductor/referidos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_api.dart';

http.Response Function(http.Request) _con(Map<String, dynamic> d) => (_) => jsonResp(d);

Future<void> _abrir(WidgetTester tester) async {
  pantallaAlta(tester);
  await tester.pumpWidget(const MaterialApp(home: ReferidosScreen()));
  await avanzar(tester, 0.5);
}

void main() {
  testWidgets('muestra el código, los botones, el progreso y los invitados', (tester) async {
    await conApiFalsa(
      _con({
        'programaActivo': true,
        'codigo': 'LUIS7K',
        'reglas': {
          'viajesMeta': 10,
          'diasMeta': 30,
          'invitado': {'pct': 0, 'viajes': 10},
          'referidor': {'pct': 5, 'viajes': 20, 'diasUso': 60},
        },
        'invitados': [
          {'nombre': 'Ana', 'viajes': 3, 'meta': 10, 'estado': 'pendiente', 'venceEn': '2030-01-01T00:00:00Z'},
        ],
        'cupones': [
          {'tipo': 'referidor', 'pct': 5, 'usosRestantes': 4, 'venceEn': '2030-01-01T00:00:00Z'},
        ],
        'miProgreso': {'viajes': 2, 'meta': 10, 'venceEn': '2030-01-01T00:00:00Z'},
      }),
      () async {
        await _abrir(tester);
        expect(find.text('LUIS7K'), findsOneWidget);
        expect(find.text('Compartir por WhatsApp'), findsOneWidget);
        expect(find.text('Copiar'), findsOneWidget);
        expect(find.textContaining('Viaje 2 de 10'), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('Viaje 3 de 10'), findsOneWidget);
        expect(find.text('En curso'), findsOneWidget);
        expect(find.textContaining('5 % de comisión'), findsWidgets);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  testWidgets('programa apagado: solo el aviso', (tester) async {
    await conApiFalsa(_con({'programaActivo': false}), () async {
      await _abrir(tester);
      expect(find.text('El programa de referidos no está activo por ahora.'), findsOneWidget);
      expect(find.text('Copiar'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('falla: error con Reintentar', (tester) async {
    await conApiFalsa((_) => errorResp(500), () async {
      await _abrir(tester);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
