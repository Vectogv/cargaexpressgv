import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/providers/notification_provider.dart';
import 'package:cargaexpress/screens/home_by_role.dart';
import 'package:cargaexpress/services/session_monitor_service.dart';

void main() {
  tearDown(() => SessionMonitorService.instance.stop());

  testWidgets('tras login/registro se inician notificaciones y monitor de sesión', (tester) async {
    SessionMonitorService.instance.stop();
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

    expect(find.text('Inicio'), findsOneWidget);
    expect(NotificationProvider.instance.iniciado, isTrue);
    expect(SessionMonitorService.instance.activo, isTrue);
    SessionMonitorService.instance.stop(); // su Timer periódico
  });

  test('NotificationProvider.init es idempotente', () {
    NotificationProvider.instance.init();
    NotificationProvider.instance.init();
    expect(NotificationProvider.instance.iniciado, isTrue);
    // Un solo juego de listeners de socket (antes cada init() duplicaba las
    // notificaciones).
    expect(NotificationProvider.instance.vecesSuscrito, 1);
  });
}
