import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/support_screen.dart';
import 'package:cargaexpress/screens/shared/cuenta_no_activa_dialog.dart';
import 'package:cargaexpress/services/api/http_client.dart' show ApiException;

import '../../helpers/fake_api.dart';

/// Cuenta suspendida (no por pago): diálogo con acceso a Soporte. Cuenta no
/// activa por pago: el destino de "Ir a Pagos" es configurable (el conductor
/// va a Ganancias/Pagos, el cliente a Pagos).
void main() {
  Future<void> abrirSuspendida(WidgetTester tester, {VoidCallback? onSoporte}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarCuentaSuspendidaDialog(context, 'Tu cuenta fue suspendida por el administrador.', onSoporte: onSoporte),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await avanzar(tester, 0.5);
  }

  testWidgets('cuenta suspendida: muestra el motivo y "Soporte" abre la pantalla de soporte con el contacto', (tester) async {
    await conApiFalsa(
      (req) => req.url.path == '/api/support/help'
          ? jsonResp({
              'faq': [],
              'contacto': {'email': 'soporte@cargaexpress.co', 'telefono': '+57 300 000 0000'},
            })
          : jsonResp({}),
      () async {
        await abrirSuspendida(tester);
        expect(find.text('Cuenta suspendida'), findsOneWidget);
        expect(find.text('Tu cuenta fue suspendida por el administrador.'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_contactar_soporte')));
        await avanzar(tester, 1);
        expect(find.byType(CuentaSuspendidaDialog), findsNothing);
        expect(find.byType(SupportScreen), findsOneWidget);
        // Sin sesión (los tokens ya se limpiaron) igual se ven teléfono y
        // correo: GET /api/support/help es público.
        expect(find.text('+57 300 000 0000'), findsOneWidget);
        expect(find.text('soporte@cargaexpress.co'), findsOneWidget);
        expect(find.byKey(const Key('soporte_sin_sesion')), findsNothing);
      },
    );
  });

  testWidgets('"Cerrar" sólo cierra; con onSoporte propio se usa ese destino', (tester) async {
    var abiertos = 0;
    await abrirSuspendida(tester, onSoporte: () => abiertos++);
    await tester.tap(find.byKey(const Key('btn_cerrar_cuenta_suspendida')));
    await avanzar(tester, 0.5);
    expect(find.byType(CuentaSuspendidaDialog), findsNothing);
    expect(abiertos, 0);

    await tester.tap(find.text('Abrir'));
    await avanzar(tester, 0.5);
    await tester.tap(find.byKey(const Key('btn_contactar_soporte')));
    await avanzar(tester, 0.5);
    expect(abiertos, 1);
    expect(find.byType(SupportScreen), findsNothing);
  });

  testWidgets('cuenta no activa por pago: "Ir a Pagos" usa el destino indicado (Pagos del conductor)', (tester) async {
    var pagosAbiertos = 0;
    final error = ApiException(
      'Tu cuenta está suspendida por falta de pago de la comisión.',
      statusCode: 403,
      code: 'CUENTA_SUSPENDIDA_POR_PAGO',
      data: {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 15000},
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarCuentaNoActivaDialog(context, error, onIrAPagos: () => pagosAbiertos++),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await avanzar(tester, 0.5);
    expect(find.text('Tienes un saldo pendiente'), findsOneWidget);
    expect(find.text('\$15.000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn_ir_a_pagos')));
    await avanzar(tester, 0.5);
    expect(pagosAbiertos, 1);
    expect(find.byType(CuentaNoActivaDialog), findsNothing);
  });
}
