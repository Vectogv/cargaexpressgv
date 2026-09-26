import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/contracts/socket_events.dart';
import 'package:cargaexpress/contracts/solicitud.dart';
import 'package:cargaexpress/screens/conductor/earnings_screen.dart';
import 'package:cargaexpress/screens/conductor/home_screen.dart';
import 'package:cargaexpress/screens/shared/cuenta_no_activa_dialog.dart';
import 'package:cargaexpress/screens/shared/tickets/nuevo_ticket_screen.dart';
import 'package:cargaexpress/screens/conductor/solicitudes_disponibles_section.dart';
import 'package:cargaexpress/services/socket_service_client.dart';
import 'package:cargaexpress/services/solicitudes_disponibles_service.dart';

import '../../helpers/fake_api.dart';

/// Inicio del conductor tras la limpieza: un solo aviso, solicitudes primero,
/// resumen compacto, mapa plegable y sin "Accesos rápidos".
void main() {
  Map<String, dynamic> perfil = {};
  Map<String, dynamic> deuda = {};
  Completer<http.Response>? perfilPendiente;

  FutureOr<http.Response> backend(http.Request req) {
    final p = req.url.path;
    if (p == '/api/users/profile') {
      final pendiente = perfilPendiente;
      if (pendiente != null) return pendiente.future;
      return jsonResp(perfil);
    }
    if (p == '/api/payment/debt') return jsonResp(deuda);
    if (p == '/api/trips/active') return errorResp(404, 'Sin viaje');
    if (p == '/api/drivers/status') return jsonResp({'online': req.body.contains('true')});
    if (p == '/api/trips/nearby') return jsonResp([]);
    if (p == '/api/drivers/offers') return jsonResp([]);
    if (p == '/api/drivers/today-stats') return jsonResp({'netaHoy': 45000, 'viajesHoy': 3, 'calificacion': 4.8});
    if (p == '/api/drivers/earnings/history') return jsonResp({'data': [], 'total': 0});
    if (p == '/api/drivers/earnings') {
      const periodo = {'neto': 0, 'bruto': 0, 'comision': 0, 'viajes': 0};
      return jsonResp({'hoy': periodo, 'semana': periodo, 'mes': periodo, 'total': periodo});
    }
    return jsonResp({});
  }

  setUp(() {
    perfil = {'id': 1, 'nombre': 'Luis', 'conductor': {'estadoVerificacion': 'aprobado'}};
    deuda = {'estadoCuenta': 'activa', 'montoDeuda': 0};
    perfilPendiente = null;
    SolicitudesDisponiblesService.instance.reiniciarParaTest();
  });

  tearDown(() => SolicitudesDisponiblesService.instance.reiniciarParaTest());

  Future<void> abrir(WidgetTester tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await avanzar(tester, 2);
  }

  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await avanzar(tester, 1);
  }

  testWidgets('orden: solicitudes disponibles → resumen del día → mapa plegable; sin "Accesos rápidos"', (tester) async {
    await conApiFalsa(backend, () async {
      await abrir(tester);

      expect(find.text('Accesos rápidos'), findsNothing);
      expect(find.text('Mis viajes'), findsNothing);
      expect(find.text('Solicitudes disponibles'), findsOneWidget);

      final solicitudes = tester.getTopLeft(find.byType(SolicitudesDisponiblesSection)).dy;
      final resumen = tester.getTopLeft(find.byKey(const Key('resumen_dia'))).dy;
      final mapa = tester.getTopLeft(find.byKey(const Key('alternar_mapa'))).dy;
      expect(solicitudes, lessThan(resumen));
      expect(resumen, lessThan(mapa));

      // Resumen compacto con los datos del día.
      expect(find.text('\$45.000'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);

      // El mapa se pliega y se despliega.
      expect(find.byKey(const Key('mini_mapa_sin_posicion')), findsOneWidget);
      await tester.tap(find.byKey(const Key('alternar_mapa')));
      await tester.pump();
      expect(find.byKey(const Key('mini_mapa_sin_posicion')), findsNothing);
      await tester.tap(find.byKey(const Key('alternar_mapa')));
      await tester.pump();
      expect(find.byKey(const Key('mini_mapa_sin_posicion')), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('"Completa tu registro" no aparece mientras el perfil carga; sí cuando llega sin conductor', (tester) async {
    perfilPendiente = Completer<http.Response>();
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.byKey(const Key('aviso_registro_incompleto')), findsNothing);
      expect(find.text('Completa tu registro como conductor'), findsNothing);

      perfilPendiente!.complete(jsonResp({'id': 1, 'nombre': 'Luis', 'conductor': null}));
      await avanzar(tester, 2);
      expect(find.byKey(const Key('aviso_registro_incompleto')), findsOneWidget);
      expect(find.text('Completa tu registro como conductor'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('con varios motivos sólo sale el aviso más importante (bloqueo por pago antes que verificación)', (tester) async {
    perfil = {'id': 1, 'nombre': 'Luis', 'conductor': {'estadoVerificacion': 'pendiente'}};
    deuda = {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 15000};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.byKey(const Key('aviso_cuenta_pago')), findsOneWidget);
      expect(find.byKey(const Key('aviso_verificacion')), findsNothing);
      await cerrar(tester);
    });
  });

  testWidgets('verificación pendiente sin deuda: un solo aviso que lleva a Documentación', (tester) async {
    perfil = {'id': 1, 'nombre': 'Luis', 'conductor': {'estadoVerificacion': 'pendiente'}};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.byKey(const Key('aviso_verificacion')), findsOneWidget);
      expect(find.text('Verificación pendiente'), findsOneWidget);
      expect(find.byKey(const Key('aviso_cuenta_pago')), findsNothing);
      expect(find.byKey(const Key('aviso_registro_incompleto')), findsNothing);
      await cerrar(tester);
    });
  });

  test('distancia hasta la recogida: sin GPS y con distancia 0 del backend no se muestra; a menos de 100 m no dice "0.0 km"', () {
    final viaje = {
      'origen': {'lat': 4.6, 'lng': -74.0},
      'distancia': 0,
    };
    expect(SolicitudDisponibleCard.kmHastaRecogida(viaje, null, null), isNull);
    expect(SolicitudDisponibleCard.kmHastaRecogida({...viaje, 'distancia': 2.3}, null, null), 2.3);
    // Con GPS justo en el origen (p. ej. cliente y conductor en el mismo emulador).
    expect(SolicitudDisponibleCard.kmHastaRecogida(viaje, 4.6, -74.0), closeTo(0, 0.001));
    expect(textoDistanciaRecogida(0.0), 'A menos de 100 m de la recogida');
    expect(textoDistanciaRecogida(0.04), 'A menos de 100 m de la recogida');
    expect(textoDistanciaRecogida(2.31), '2.3 km hasta la recogida');
    expect(textoDistanciaRecogida(12.6), '13 km hasta la recogida');
  });

  testWidgets('suspensión por pago en caliente: diálogo con el monto y "Ir a Pagos" abre Pagos del conductor', (tester) async {
    await conApiFalsa(backend, () async {
      await abrir(tester);
      deuda = {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 20000};
      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.accountPaymentSuspended, {
        'estadoCuenta': 'suspension_por_pago',
        'code': 'CUENTA_SUSPENDIDA_POR_PAGO',
        'montoDeuda': 20000,
        'online': false,
        'message': 'Tu deuda de comisión venció.',
      });
      await avanzar(tester, 1);
      expect(find.byType(CuentaNoActivaDialog), findsOneWidget);
      expect(find.text('Tu deuda de comisión venció.'), findsOneWidget);
      expect(find.text('\$20.000'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_ir_a_pagos')));
      await avanzar(tester, 1);
      expect(find.byType(CuentaNoActivaDialog), findsNothing);
      expect(find.byType(EarningsScreen), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('suspendido por pago: el aviso del inicio también ofrece Soporte', (tester) async {
    deuda = {'estadoCuenta': 'suspension_por_pago', 'montoDeuda': 20000};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      expect(find.byKey(const Key('aviso_cuenta_pago')), findsOneWidget);
      await tester.tap(find.byKey(const Key('aviso_pago_soporte')));
      await avanzar(tester, 1);
      // Abre un ticket de pagos con el asunto ya escrito.
      expect(find.byType(NuevoTicketScreen), findsOneWidget);
      expect(find.text('Ya pagué y mi cuenta sigue suspendida'), findsOneWidget);
      await cerrar(tester);
    });
  });

  testWidgets('cuenta no aprobada: al intentar conectarse se ofrece ir a Documentos', (tester) async {
    perfil = {'id': 1, 'nombre': 'Luis', 'conductor': {'estadoVerificacion': 'pendiente'}};
    await conApiFalsa(backend, () async {
      await abrir(tester);
      final interruptor = tester.widget<Switch>(find.byType(Switch));
      expect(interruptor.value, isFalse);
      await tester.tap(find.byType(Switch));
      await avanzar(tester, 1);
      expect(find.text('Tu cuenta no está aprobada para recibir viajes'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Documentos'), findsOneWidget);
      await cerrar(tester);
    });
  });
}
