import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/cliente/home_screen.dart';
import 'package:cargaexpress/screens/cliente/pagos_screen.dart';
import 'package:cargaexpress/screens/cliente/soporte_screen.dart';

import '../../helpers/fake_api.dart';

http.Response _base(http.Request req, Object? pagos) {
  final p = req.url.path;
  if (p == '/api/trips/active') return errorResp(404, 'Sin viaje');
  if (p == '/api/payments') {
    return pagos is http.Response ? pagos : jsonResp(pagos);
  }
  return jsonResp({'data': []});
}

Future<void> _abrirMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menú'));
  await avanzar(tester);
}

void main() {
  group('tieneDeudaPendiente (GET /api/payments)', () {
    test('cuenta al día sin deuda', () {
      expect(tieneDeudaPendiente({'estadoCuenta': 'activa', 'montoDeuda': null}), isFalse);
      expect(tieneDeudaPendiente({'estadoCuenta': 'activa', 'montoDeuda': '0.00'}), isFalse);
      expect(tieneDeudaPendiente(null), isFalse);
    });

    test('suspensión por pago, comprobante en revisión o monto pendiente', () {
      expect(tieneDeudaPendiente({'estadoCuenta': 'suspension_por_pago'}), isTrue);
      expect(tieneDeudaPendiente({'estadoCuenta': 'esperando_confirmacion'}), isTrue);
      expect(tieneDeudaPendiente({'estadoCuenta': 'activa', 'montoDeuda': '15000.00'}), isTrue);
      expect(tieneDeudaPendiente({'estadoCuenta': 'activa', 'montoDeuda': 15000}), isTrue);
      expect(tieneDeudaPendiente({'tieneDeudaActiva': true}), isTrue);
    });

    test('suspensión por pago', () {
      expect(cuentaSuspendidaPorPago({'estadoCuenta': 'suspension_por_pago'}), isTrue);
      expect(cuentaSuspendidaPorPago({'estadoCuenta': 'esperando_confirmacion'}), isFalse);
    });
  });

  testWidgets('sin deuda: Pagos no aparece en el menú ni hay aviso', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => _base(req, {'estadoCuenta': 'activa', 'montoDeuda': null}), () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      expect(find.byKey(const Key('aviso_pago_pendiente')), findsNothing);
      await _abrirMenu(tester);
      expect(find.text('Mis viajes'), findsOneWidget);
      expect(find.text('Pagos'), findsNothing);
    });
  });

  testWidgets('si /api/payments falla, Pagos queda oculto', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => _base(req, errorResp(500)), () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      await _abrirMenu(tester);
      expect(find.text('Pagos'), findsNothing);
    });
  });

  testWidgets('deuda tras disputa sin suspensión: Pagos en el menú, sin aviso', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) => _base(req, {'estadoCuenta': 'activa', 'montoDeuda': '20000.00'}), () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      expect(find.byKey(const Key('aviso_pago_pendiente')), findsNothing);
      await _abrirMenu(tester);
      expect(find.text('Pagos'), findsOneWidget);
      expect(find.text('Pendiente'), findsNothing);
    });
  });

  testWidgets('suspendido por pago: aviso en el inicio que abre Pagos y Pagos destacado en el menú',
      (tester) async {
    pantallaAlta(tester);
    await conApiFalsa(
        (req) => _base(req, {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': '20000.00', 'diasRestantes': 3}),
        () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      expect(find.text('Tienes un pago pendiente'), findsOneWidget);

      await _abrirMenu(tester);
      expect(find.text('Pagos'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      await tester.tap(find.text('Pagos'));
      await avanzar(tester);
      expect(find.byType(PagosScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await avanzar(tester);
      await tester.tap(find.byKey(const Key('aviso_pago_pendiente')));
      await avanzar(tester);
      expect(find.byType(PagosScreen), findsOneWidget);
    });
  });

  testWidgets('el admin libera la cuenta: al volver al inicio desaparece el aviso', (tester) async {
    pantallaAlta(tester);
    Object deuda = {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': '90000.00'};
    await conApiFalsa((req) => _base(req, deuda), () async {
      await tester.pumpWidget(const MaterialApp(home: ClienteHomeScreen()));
      await avanzar(tester);
      expect(find.text('Tienes un pago pendiente'), findsOneWidget);

      await tester.tap(find.text('Soporte').first);
      await avanzar(tester);
      deuda = {'estadoCuenta': 'activa', 'montoDeuda': null};
      Navigator.of(tester.element(find.byType(SoporteScreen))).pop();
      await avanzar(tester);
      expect(find.text('Tienes un pago pendiente'), findsNothing);
    });
  });
}
