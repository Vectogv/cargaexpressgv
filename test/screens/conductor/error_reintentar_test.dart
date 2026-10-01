import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/earnings_screen.dart';
import 'package:cargaexpress/screens/conductor/trip_history_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  testWidgets('historial de viajes: si falla muestra error con Reintentar y se recupera', (tester) async {
    var falla = true;
    await conApiFalsa((req) {
      if (falla) return errorResp(500);
      return jsonResp({'data': [], 'total': 0});
    }, () async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: TripHistoryScreen()));
      await avanzar(tester);
      expect(find.text('No se pudo cargar el historial'), findsOneWidget);
      expect(find.text('Sin viajes anteriores'), findsNothing);
      falla = false;
      await tester.tap(find.text('Reintentar'));
      await avanzar(tester);
      expect(find.text('No se pudo cargar el historial'), findsNothing);
    });
  });

  testWidgets('ganancias: si falla muestra error con Reintentar (no ceros)', (tester) async {
    await conApiFalsa((req) => errorResp(500), () async {
      pantallaAlta(tester);
      await tester.pumpWidget(const MaterialApp(home: EarningsScreen()));
      await avanzar(tester);
      expect(find.text('No se pudieron cargar tus ganancias'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
