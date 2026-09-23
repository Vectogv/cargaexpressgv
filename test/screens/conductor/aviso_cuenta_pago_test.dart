import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/aviso_cuenta_pago.dart';

void main() {
  test('estado de pago a partir de GET /api/payment/debt', () {
    expect(estadoPagoConductor(null), EstadoPagoConductor.alDia);
    expect(estadoPagoConductor({'estadoCuenta': 'activa', 'montoDeuda': 0}), EstadoPagoConductor.alDia);
    expect(estadoPagoConductor({'estadoCuenta': 'activa', 'montoDeuda': '15000.00'}), EstadoPagoConductor.conDeuda);
    expect(estadoPagoConductor({'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 15000}), EstadoPagoConductor.suspendida);
    expect(estadoPagoConductor({'estadoCuenta': 'esperando_confirmacion'}), EstadoPagoConductor.enRevision);
    expect(EstadoPagoConductor.suspendida.bloqueaConexion, isTrue);
    expect(EstadoPagoConductor.enRevision.bloqueaConexion, isTrue);
    expect(EstadoPagoConductor.conDeuda.bloqueaConexion, isFalse);
  });

  Future<int> pintar(WidgetTester tester, Map<String, dynamic>? deuda) async {
    var abiertos = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AvisoCuentaPago(deuda: deuda, onAbrirPagos: () => abiertos++)),
    ));
    final boton = find.byType(OutlinedButton);
    if (boton.evaluate().isNotEmpty) {
      await tester.tap(boton);
      await tester.pump();
    }
    return abiertos;
  }

  testWidgets('suspendida: título claro, monto y botón a pagos', (tester) async {
    final abiertos = await pintar(tester, {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 15000});
    expect(find.text('Cuenta suspendida por pago pendiente'), findsOneWidget);
    expect(find.textContaining('\$15.000'), findsOneWidget);
    expect(abiertos, 1);
  });

  testWidgets('comprobante en revisión', (tester) async {
    await pintar(tester, {'estadoCuenta': 'esperando_confirmacion', 'montoDeuda': 15000});
    expect(find.text('Pago en revisión'), findsOneWidget);
  });

  testWidgets('con deuda sin suspender: monto y fecha límite', (tester) async {
    await pintar(tester, {
      'estadoCuenta': 'activa',
      'montoDeuda': '20000.00',
      'deudaFechaLimite': '2026-10-08T12:00:00.000-05:00',
    });
    expect(find.textContaining('\$20.000'), findsOneWidget);
    expect(find.textContaining('Paga antes del 08/10/2026'), findsOneWidget);
  });

  testWidgets('al día: no muestra nada', (tester) async {
    final abiertos = await pintar(tester, {'estadoCuenta': 'activa', 'montoDeuda': 0});
    expect(find.byType(OutlinedButton), findsNothing);
    expect(abiertos, 0);
  });
}
