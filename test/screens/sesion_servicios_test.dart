import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/screens/home_by_role.dart';
import 'package:cargaexpress/services/notification_service.dart';
import 'package:cargaexpress/services/session_monitor_service.dart';

import '../helpers/fake_api.dart';

void main() {
  final notif = NotificationService.instance;
  // Sin plataforma: el permiso de notificaciones no se pide en pruebas.
  setUp(() => notif.pedirPermisoNotificaciones = () async {});
  tearDown(() {
    SessionMonitorService.instance.stop();
    notif.fcmTokenParaTest = null;
    notif.hasSession = () => false;
    notif.obtenerTokenFcm = () async => null;
  });

  testWidgets('tras login/registro arranca el monitor de sesión y se registra el token FCM', (tester) async {
    SessionMonitorService.instance.stop();
    notif.fcmTokenParaTest = 'fcm-123';
    notif.hasSession = () => true;
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({'ok': true}), () async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => abrirInicioComoRaiz(ctx, const Text('Inicio')),
            child: const Text('Entrar'),
          ),
        ),
      ));

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
    }, log: log);

    expect(find.text('Inicio'), findsOneWidget);
    expect(SessionMonitorService.instance.activo, isTrue);
    expect(log.where((r) => r.method == 'PUT' && r.url.path == '/api/users/fcm-token'), hasLength(1));
    SessionMonitorService.instance.stop(); // su Timer periódico
  });

  test('sin token FCM (Firebase no devuelve ninguno) no se llama al backend', () async {
    notif.fcmTokenParaTest = null;
    notif.hasSession = () => true;
    notif.obtenerTokenFcm = () async => null;
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({}), () => notif.registrarTokenSesion(), log: log);
    expect(log, isEmpty);
  });

  test('si obtener el token falla, se reintenta y se informa el motivo al backend', () async {
    notif.fcmTokenParaTest = null;
    notif.hasSession = () => true;
    var intentos = 0;
    notif.obtenerTokenFcm = () async {
      intentos++;
      if (intentos < 3) throw Exception('SERVICE_NOT_AVAILABLE');
      return 'fcm-tras-reintento';
    };
    final log = <http.Request>[];
    await conApiFalsa((_) => jsonResp({}), () => notif.registrarTokenSesion(), log: log);
    expect(intentos, 3);
    expect(log.single.body, contains('fcm-tras-reintento'));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
