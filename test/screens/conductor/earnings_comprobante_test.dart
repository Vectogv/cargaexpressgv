import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/conductor/earnings_screen.dart';

import '../../helpers/fake_api.dart';

void main() {
  Map<String, dynamic> deuda = {};

  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/payment/debt') return jsonResp(deuda);
    if (p == '/api/drivers/earnings/history') return jsonResp({'data': [], 'total': 0});
    if (p == '/api/drivers/earnings') {
      const periodo = {'neto': 0, 'bruto': 0, 'comision': 0, 'viajes': 0};
      return jsonResp({'hoy': periodo, 'semana': periodo, 'mes': periodo, 'total': periodo});
    }
    return jsonResp({});
  }

  Future<void> abrir(WidgetTester tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: EarningsScreen()));
    await avanzar(tester);
  }

  testWidgets('comprobante en revisión: muestra su monto y explica la deuda adicional', (tester) async {
    deuda = {'estadoCuenta': 'esperando_confirmacion', 'montoDeuda': 20000, 'montoComprobante': 12000, 'diasRestantes': 0};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      await tester.scrollUntilVisible(find.text('Comprobante en revisión por \$12.000'), 200);
      expect(find.text('Comprobante en revisión por \$12.000'), findsOneWidget);
      expect(find.textContaining('\$8.000'), findsOneWidget);
      expect(find.textContaining('viajes terminados mientras se revisa'), findsOneWidget);
    });
  });

  testWidgets('comprobante que cubre toda la deuda: sin explicación adicional', (tester) async {
    deuda = {'estadoCuenta': 'esperando_confirmacion', 'montoDeuda': '12000.00', 'montoComprobante': 12000, 'diasRestantes': 0};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      await tester.scrollUntilVisible(find.text('Comprobante en revisión por \$12.000'), 200);
      expect(find.textContaining('viajes terminados mientras se revisa'), findsNothing);
      expect(find.text('Subir comprobante de pago'), findsNothing);
    });
  });

  testWidgets('con deuda y cuenta activa ya puede subir el comprobante (no espera la suspensión)', (tester) async {
    deuda = {'estadoCuenta': 'activa', 'montoDeuda': '11300.00', 'diasRestantes': 13};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.text('Subir comprobante de pago'), findsOneWidget);
    });
  });

  testWidgets('sin deuda: no hay botón de comprobante', (tester) async {
    deuda = {'estadoCuenta': 'activa', 'montoDeuda': 0};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      await tester.scrollUntilVisible(find.text('No tienes deudas pendientes'), 200);
      expect(find.text('Subir comprobante de pago'), findsNothing);
    });
  });
}
