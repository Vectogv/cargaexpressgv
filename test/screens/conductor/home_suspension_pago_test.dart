import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/contracts/socket_events.dart';
import 'package:cargaexpress/screens/conductor/home_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

void main() {
  Map<String, dynamic> deuda = {};

  http.Response backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/users/profile') {
      return jsonResp({'id': 1, 'nombre': 'Luis', 'conductor': {'estadoVerificacion': 'aprobado'}});
    }
    if (p == '/api/payment/debt') return jsonResp(deuda);
    if (p == '/api/trips/active') return errorResp(404, 'Sin viaje');
    if (p == '/api/drivers/status') {
      if (deuda['estadoCuenta'] == 'activa') return jsonResp({'online': req.body.contains('true')});
      return jsonResp({
        'error': 'Tu cuenta está suspendida por falta de pago de la comisión.',
        'code': 'CUENTA_SUSPENDIDA_POR_PAGO',
        'estadoCuenta': 'suspension_por_pago',
      }, 403);
    }
    return jsonResp({});
  }

  Switch interruptor(WidgetTester tester) => tester.widget<Switch>(find.byType(Switch));

  testWidgets('suspendido por pago: aviso, no se conecta solo y el interruptor queda bloqueado', (tester) async {
    pantallaAlta(tester);
    deuda = {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 15000, 'deudaFechaLimite': null};
    final log = <http.Request>[];
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await avanzar(tester, 2);

      expect(find.text('Cuenta suspendida por pago pendiente'), findsOneWidget);
      expect(interruptor(tester).value, isFalse);
      expect(interruptor(tester).onChanged, isNull);
      expect(find.text('Suspendido por pago: paga para conectarte'), findsOneWidget);

      // El admin aprueba el pago: se puede volver a conectar.
      deuda = {'estadoCuenta': 'activa', 'montoDeuda': 0};
      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.paymentConfirmed, {
        'message': 'Tu pago ha sido confirmado. Tu cuenta está activa nuevamente.',
      });
      await avanzar(tester, 1);
      expect(find.text('Cuenta suspendida por pago pendiente'), findsNothing);
      expect(interruptor(tester).onChanged, isNotNull);
      expect(find.text('Tu pago ha sido confirmado. Tu cuenta está activa nuevamente.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await avanzar(tester, 1);
    }, log: log);

    expect(log.where((r) => r.url.path == '/api/drivers/status' && r.body.contains('true')), isEmpty);
  });

  testWidgets('payment:confirmed con saldo restante: avisa cuánto queda y mantiene el aviso de deuda', (tester) async {
    pantallaAlta(tester);
    deuda = {'estadoCuenta': 'esperando_confirmacion', 'montoDeuda': 20000, 'montoComprobante': 12000};
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await avanzar(tester, 2);
      expect(find.text('Pago en revisión'), findsOneWidget);

      deuda = {'estadoCuenta': 'activa', 'montoDeuda': 8000, 'deudaFechaLimite': '2026-10-08T12:00:00.000-05:00'};
      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.paymentConfirmed, {
        'message': 'Tu pago ha sido confirmado y tu cuenta está activa. Te queda una deuda de \$8.000...',
        'estadoCuenta': 'activa',
        'montoDeuda': 8000,
        'deudaFechaLimite': '2026-10-08T12:00:00.000-05:00',
      });
      await tester.pump();
      await tester.pump();
      // Sin esperar a recargar la deuda: el aviso ya refleja el saldo.
      expect(find.text('Deuda de comisión: \$8.000'), findsOneWidget);
      await avanzar(tester, 1);
      expect(find.text('Pago aprobado. Te quedan \$8.000 por pagar antes del 08/10/2026'), findsOneWidget);
      expect(find.text('Deuda de comisión: \$8.000'), findsOneWidget);
      expect(find.text('Cuenta suspendida por pago pendiente'), findsNothing);
      expect(interruptor(tester).onChanged, isNotNull);

      await tester.pumpWidget(const SizedBox());
      await avanzar(tester, 1);
    });
  });

  testWidgets('payment:confirmed sin saldo quita el aviso de deuda', (tester) async {
    pantallaAlta(tester);
    deuda = {'estadoCuenta': 'esperando_confirmacion', 'montoDeuda': 12000, 'montoComprobante': 12000};
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await avanzar(tester, 2);
      deuda = {'estadoCuenta': 'activa', 'montoDeuda': null};
      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.paymentConfirmed, {
        'message': 'Tu pago ha sido confirmado. Tu cuenta está activa nuevamente.',
        'estadoCuenta': 'activa',
        'montoDeuda': 0,
        'deudaFechaLimite': null,
      });
      await avanzar(tester, 1);
      expect(find.byKey(const Key('aviso_cuenta_pago')), findsNothing);
      expect(find.text('Tu pago ha sido confirmado. Tu cuenta está activa nuevamente.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await avanzar(tester, 1);
    });
  });

  testWidgets('account:payment_suspended lo desconecta y muestra el aviso sin cerrar sesión', (tester) async {
    pantallaAlta(tester);
    deuda = {'estadoCuenta': 'activa', 'montoDeuda': 20000, 'deudaFechaLimite': '2026-10-08T12:00:00.000-05:00'};
    await conApiFalsa(backend, () async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await avanzar(tester, 2);
      expect(find.textContaining('Paga antes del 08/10/2026'), findsOneWidget);

      deuda = {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 20000};
      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.accountPaymentSuspended, {
        'estadoCuenta': 'suspension_por_pago',
        'code': 'CUENTA_SUSPENDIDA_POR_PAGO',
        'montoDeuda': 20000,
        'online': false,
        'message': 'Tu deuda de comisión venció.',
      });
      await avanzar(tester, 1);
      expect(find.text('Cuenta suspendida por pago pendiente'), findsOneWidget);
      expect(interruptor(tester).value, isFalse);
      expect(interruptor(tester).onChanged, isNull);
      expect(find.text('Tu deuda de comisión venció.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await avanzar(tester, 1);
    });
  });
}
