import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/moderador/moderador_home_screen.dart';
import 'package:cargaexpress/services/api/http_client.dart';
import 'package:cargaexpress/services/api/moderator_service.dart';

class _FakeModeratorService extends ModeratorService {
  List<Map<String, dynamic>> cierres;
  List<Map<String, dynamic>> emergencias;
  Object? resolveError;
  int pendingCloseCalls = 0;
  final List<Map<String, dynamic>> resolveCalls = [];

  _FakeModeratorService({this.cierres = const [], this.emergencias = const []});

  @override
  Future<Map<String, dynamic>> getDashboard() async =>
      {'ciudad': 'cali', 'totalDrivers': 12, 'onlineDrivers': 5, 'inactiveDrivers': 2};

  @override
  Future<List<Map<String, dynamic>>> getPendingCloses() async {
    pendingCloseCalls++;
    return cierres;
  }

  @override
  Future<List<Map<String, dynamic>>> getEmergencies({String? estado}) async => emergencias;

  @override
  Future<Map<String, dynamic>> resolvePendingClose(dynamic tripId,
      {required String resolucion, required String nota}) async {
    resolveCalls.add({'id': tripId, 'resolucion': resolucion, 'nota': nota});
    if (resolveError != null) throw resolveError!;
    return {'id': tripId, 'estado': 'finalizado'};
  }
}

Map<String, dynamic> _viaje(String id) => {
      'id': id,
      'estado': 'pendiente_confirmacion',
      'origenDireccion': 'Calle 1',
      'destinoDireccion': 'Calle 2',
      'cliente': {'nombre': 'Ana', 'telefono': '300'},
      'conductor': {'nombre': 'Luis', 'placa': 'ABC123'},
    };

Future<void> _pump(WidgetTester tester, ModeratorService service,
    {Stream<Map<String, dynamic>>? eventos}) async {
  await tester.pumpWidget(MaterialApp(
    home: ModeradorHomeScreen(
      service: service,
      eventos: eventos ?? const Stream.empty(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el resumen de la zona', (tester) async {
    await _pump(tester, _FakeModeratorService());
    expect(find.text('Moderación'), findsOneWidget);
    expect(find.text('Zona: cali'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('lista vacía de cierres muestra estado vacío', (tester) async {
    await _pump(tester, _FakeModeratorService());
    await tester.tap(find.text('Cierres'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay viajes esperando'), findsOneWidget);
  });

  testWidgets('resolver cierre muestra el mensaje del backend ante 409', (tester) async {
    final service = _FakeModeratorService(cierres: [_viaje('7')])
      ..resolveError = ApiException(
        'El cliente aun esta dentro del plazo de confirmacion',
        statusCode: 409,
        code: 'CONFIRMACION_EN_PLAZO',
      );
    await _pump(tester, service);
    await tester.tap(find.text('Cierres (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Viaje #7'), findsOneWidget);
    await tester.tap(find.text('Resolver cierre'));
    await tester.pumpAndSettle();

    // Nota corta: validación local, no llama al backend.
    await tester.enterText(find.byType(TextField), 'corta');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('La nota debe tener al menos 10 caracteres'), findsOneWidget);
    expect(service.resolveCalls, isEmpty);

    await tester.tap(find.text('Enviar a disputa'));
    await tester.enterText(find.byType(TextField), 'El cliente reporta danos en la carga');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(service.resolveCalls.single['resolucion'], 'disputa');
    expect(service.resolveCalls.single['id'], '7');
    expect(find.text('El cliente aun esta dentro del plazo de confirmacion'), findsOneWidget);
  });

  testWidgets('un evento de moderador por socket refresca la lista', (tester) async {
    final eventos = StreamController<Map<String, dynamic>>.broadcast();
    final service = _FakeModeratorService();
    await _pump(tester, service, eventos: eventos.stream);
    final antes = service.pendingCloseCalls;

    service.cierres = [_viaje('9')];
    eventos.add({'__event': 'moderator:pending_close', 'viajeId': '9'});
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(service.pendingCloseCalls, greaterThan(antes));
    expect(find.text('Cierres (1)'), findsOneWidget);
    await eventos.close();
  });

  testWidgets('emergencias pendientes se listan con acciones', (tester) async {
    await _pump(
      tester,
      _FakeModeratorService(emergencias: [
        {
          'id': 3,
          'estado': 'pendiente',
          'estadoLabel': 'Pendiente',
          'motivo': 'Robo en ruta',
          'usuario': {'nombre': 'Pedro', 'telefono': '311'},
        },
      ]),
    );
    await tester.tap(find.text('Emergencias (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Robo en ruta'), findsOneWidget);
    expect(find.text('Atender'), findsOneWidget);
    expect(find.text('Resolver'), findsOneWidget);
  });
}
