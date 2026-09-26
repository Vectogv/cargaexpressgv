import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/ajustes_screen.dart';
import 'package:cargaexpress/screens/cliente/conductor_en_la_zona_screen.dart';
import 'package:cargaexpress/screens/cliente/disputa_creada_screen.dart';
import 'package:cargaexpress/screens/cliente/disputa_en_revision_screen.dart';
import 'package:cargaexpress/screens/cliente/llegada_al_destino_screen.dart';
import 'package:cargaexpress/screens/cliente/mis_envios_screen.dart';
import 'package:cargaexpress/screens/cliente/ofertas_recibidas_screen.dart';
import 'package:cargaexpress/screens/cliente/pagos_screen.dart';
import 'package:cargaexpress/screens/cliente/soporte_screen.dart';

import '../../helpers/fake_api.dart';

/// Abre [pantalla] con el backend falso; con [falla] responde [status].
Future<void> abrir(
  WidgetTester tester,
  Widget pantalla, {
  required FakeHandler ok,
  required bool Function() falla,
  int status = 500,
  required Future<void> Function() body,
}) async {
  pantallaAlta(tester);
  await conApiFalsa((req) => falla() ? errorResp(status, 'Error del servidor') : ok(req), () async {
    await tester.pumpWidget(MaterialApp(home: pantalla));
    await avanzar(tester);
    await body();
  });
}

void main() {
  group('Mis envíos', () {
    testWidgets('abre y lista los envíos', (tester) async {
      await abrir(tester, const MisEnviosScreen(),
          ok: (_) => jsonResp({
                'data': [
                  {'_id': 't1', 'estado': 'finalizado', 'origen': {'direccion': 'Calle 1'}, 'destino': {'direccion': 'Calle 2'}},
                ],
              }),
          falla: () => false, body: () async {
        expect(find.textContaining('Calle 1'), findsWidgets);
      });
    });

    testWidgets('muestra el precio final (monto real) y si no hay, el estimado', (tester) async {
      await abrir(tester, const MisEnviosScreen(),
          ok: (_) => jsonResp({
                'data': [
                  {'_id': 't1', 'estado': 'finalizado', 'precioEstimado': 30000, 'precioFinal': 32000},
                  {'_id': 't2', 'estado': 'buscando_conductor', 'precioEstimado': '25000.00'},
                ],
              }),
          falla: () => false, body: () async {
        // Con punto de miles: "$32.000", no "$32000".
        expect(find.text('\$32.000'), findsOneWidget);
        expect(find.text('\$30.000'), findsNothing);
        expect(find.text('\$25.000'), findsOneWidget);
      });
    });

    testWidgets('error -> mensaje, sin spinner, reintentar', (tester) async {
      var falla = true;
      await abrir(tester, const MisEnviosScreen(),
          ok: (_) => jsonResp({'data': []}), falla: () => falla, body: () async {
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Error al cargar envíos'), findsOneWidget);
        falla = false;
        await tester.tap(find.text('Reintentar'));
        await avanzar(tester);
        expect(find.text('No tienes envíos'), findsOneWidget);
      });
    });
  });

  group('Pagos', () {
    testWidgets('abre con el estado de cuenta', (tester) async {
      await abrir(tester, const PagosScreen(),
          ok: (_) => jsonResp({'estadoCuenta': 'al_dia', 'diasRestantes': 5, 'montoDeuda': 0}),
          falla: () => false, body: () async {
        expect(find.text('Pagos'), findsOneWidget);
        expect(find.text('Al día'), findsWidgets);
        expect(find.text('Subir comprobante de pago'), findsNothing);
      });
    });

    testWidgets('con deuda y cuenta activa ya puede subir el comprobante (no espera la suspensión)', (tester) async {
      await abrir(tester, const PagosScreen(),
          ok: (_) => jsonResp({'estadoCuenta': 'activa', 'diasRestantes': 8, 'montoDeuda': '15000.00'}),
          falla: () => false, body: () async {
        expect(find.text('Cuenta activa'), findsOneWidget);
        expect(find.text('Subir comprobante de pago'), findsOneWidget);
        expect(find.textContaining('Puedes pagar cuando quieras'), findsOneWidget);
      });
    });

    testWidgets('suspendido: botón con el aviso de reactivar la cuenta', (tester) async {
      await abrir(tester, const PagosScreen(),
          ok: (_) => jsonResp({'estadoCuenta': 'suspension_por_pago', 'diasRestantes': 0, 'montoDeuda': 15000}),
          falla: () => false, body: () async {
        expect(find.text('Subir comprobante de pago'), findsOneWidget);
        expect(find.textContaining('Para reactivar tu cuenta'), findsOneWidget);
      });
    });

    testWidgets('comprobante en revisión: sin botón para subir otro', (tester) async {
      await abrir(tester, const PagosScreen(),
          ok: (_) => jsonResp({'estadoCuenta': 'esperando_confirmacion', 'diasRestantes': 3, 'montoDeuda': 15000}),
          falla: () => false, body: () async {
        expect(find.text('Comprobante en revisión'), findsOneWidget);
        expect(find.text('Subir comprobante de pago'), findsNothing);
      });
    });

    testWidgets('error -> mensaje y reintentar', (tester) async {
      var falla = true;
      await abrir(tester, const PagosScreen(),
          ok: (_) => jsonResp({'estadoCuenta': 'al_dia'}), falla: () => falla, status: 503, body: () async {
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('No se pudo cargar tu estado de cuenta'), findsOneWidget);
        falla = false;
        await tester.tap(find.text('Reintentar'));
        await avanzar(tester);
        expect(find.text('No se pudo cargar tu estado de cuenta'), findsNothing);
      });
    });
  });

  group('Soporte', () {
    testWidgets('abre sin conversaciones', (tester) async {
      await abrir(tester, const SoporteScreen(), ok: (_) => jsonResp([]), falla: () => false, body: () async {
        expect(find.text('No tienes conversaciones de soporte'), findsOneWidget);
      });
    });

    testWidgets('error -> mensaje y reintentar', (tester) async {
      var falla = true;
      await abrir(tester, const SoporteScreen(), ok: (_) => jsonResp([]), falla: () => falla, body: () async {
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('No se pudo cargar el soporte'), findsOneWidget);
        falla = false;
        await tester.tap(find.text('Reintentar'));
        await avanzar(tester);
        expect(find.text('No tienes conversaciones de soporte'), findsOneWidget);
      });
    });

    testWidgets('muestra el teléfono y correo de contacto (GET /api/support/help)', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((req) {
        if (req.url.path == '/api/support/help') {
          return jsonResp({
            'contacto': {'email': 'soporte@cargaexpress.co', 'telefono': '+57 300 000 0000'},
            'faq': [],
          });
        }
        return jsonResp([]);
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: SoporteScreen()));
        await avanzar(tester);
        expect(find.text('soporte@cargaexpress.co'), findsOneWidget);
        expect(find.text('+57 300 000 0000'), findsOneWidget);
      });
    });
  });

  group('Disputas', () {
    testWidgets('DisputaCreada -> Disputa en revisión', (tester) async {
      await abrir(tester, const DisputaCreadaScreen(disputeNumber: 'DSP-00005', disputeId: '5'),
          ok: (_) => jsonResp({'id': '5', 'numero': 'DSP-00005', 'estado': 'abierta'}),
          falla: () => false, body: () async {
        expect(find.text('DSP-00005'), findsOneWidget);
        await tester.tap(find.text('Ver mis disputas'));
        await avanzar(tester);
        expect(find.byType(DisputaEnRevisionScreen), findsOneWidget);
        expect(find.text('Volver al inicio'), findsOneWidget);
      });
    });

    testWidgets('en revisión: error (404) -> mensaje y reintentar', (tester) async {
      var falla = true;
      await abrir(tester, const DisputaEnRevisionScreen(disputeId: '5'),
          ok: (_) => jsonResp({'id': '5', 'numero': 'DSP-00005', 'estado': 'abierta'}),
          falla: () => falla, status: 404, body: () async {
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Error al cargar disputa'), findsOneWidget);
        falla = false;
        await tester.tap(find.text('Reintentar'));
        await avanzar(tester);
        expect(find.text('DSP-00005'), findsOneWidget);
      });
    });
  });

  testWidgets('Ofertas recibidas: si el GET falla y no hay ofertas se avisa', (tester) async {
    var falla = true;
    await abrir(
      tester,
      OfertasRecibidasScreen(ofertas: const [], tripId: 't1', trip: const {}, onAccept: (_) async {}, onReject: (_) async {}),
      ok: (_) => jsonResp([]),
      falla: () => falla,
      body: () async {
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });

  testWidgets('pantallas sin API abren con datos mínimos', (tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: AjustesScreen()));
    expect(find.text('Ajustes'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: ConductorEnLaZonaScreen(conductor: const {}, onChat: () {}, onCall: () {})));
    await avanzar(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MaterialApp(
      home: LlegadaAlDestinoScreen(conductor: const {}, trip: const {}, onVerDetalle: () {}),
    ));
    await avanzar(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Revisar y confirmar entrega'), findsOneWidget);
    expect(find.textContaining('un moderador revisará'), findsOneWidget);
  });
}
