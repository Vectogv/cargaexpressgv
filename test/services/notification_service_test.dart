import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/notifications_screen.dart';
import 'package:cargaexpress/services/api/http_client.dart';
import 'package:cargaexpress/services/notification_service.dart';

void main() {
  final service = NotificationService.instance;
  late List<Map<String, dynamic>> backend;
  late List<String> marcadas;
  late bool sesion;
  late String usuario;
  late String rol;
  Object? errorBackend;
  var llamadas = 0;

  setUp(() {
    backend = [];
    marcadas = [];
    sesion = true;
    usuario = 'u1';
    rol = 'cliente';
    errorBackend = null;
    llamadas = 0;
    service.hasSession = () => sesion;
    service.currentUser = () => usuario;
    service.currentRol = () => rol;
    service.fetchRemote = () async {
      llamadas++;
      if (errorBackend != null) throw errorBackend!;
      return backend;
    };
    service.markRemoteRead = (id) async => marcadas.add(id);
    service.resetForTest();
  });

  Map<String, dynamic> remota(String id, {bool leido = false, String fecha = '2026-09-20T10:00:00.000Z'}) => {
        'id': id,
        '_id': id,
        'tipo': 'mensaje',
        'titulo': 'Aviso $id',
        'mensaje': 'Detalle $id',
        'leido': leido,
        'createdAt': fecha,
      };

  test('eventos internos del socket no suben el badge', () {
    service.ingest({'__event': 'trip:status_changed', 'estado': 'en_curso'});
    service.ingest({'__event': 'trip:offer_received', 'id': 'x'});
    service.ingest({'foo': 'bar'});
    expect(service.unreadCount, 0);
    expect(service.notifications, isEmpty);
  });

  test('badge y lista salen de la misma fuente; marcar leída lo baja', () async {
    backend = [remota('1'), remota('2', leido: true)];
    expect(await service.refresh(), isTrue);
    expect(service.unreadCount, 1);
    expect(service.unread.value, 1);
    expect(service.notifications.map((n) => n['id']), containsAll(['1', '2']));

    await service.markRead(service.notifications.firstWhere((n) => n['id'] == '1'));
    expect(service.unreadCount, 0);
    expect(service.unread.value, 0);
    expect(marcadas, ['1']);
  });

  test('viaje cancelado por el conductor aparece en la lista; el propio no', () {
    service.ingest({'__event': 'trip:cancelled', 'id': 't1', 'canceladoPor': 'cliente'});
    expect(service.unreadCount, 0);

    service.ingest({'__event': 'trip:cancelled', 'id': 't1', 'canceladoPor': 'conductor', 'motivo': 'Avería'});
    expect(service.unreadCount, 1);
    final n = service.notifications.single;
    expect(n['titulo'], 'Viaje cancelado');
    expect(n['mensaje'], 'El conductor canceló el viaje: Avería');
  });

  test('notification:new no duplica lo que ya vino del backend y notification:read lo marca', () async {
    backend = [remota('7')];
    await service.refresh();
    service.ingest({...remota('7'), '__event': 'notification:new'});
    expect(service.notifications.length, 1);

    service.ingest({'__event': 'notification:read', 'id': '7'});
    expect(service.unreadCount, 0);

    service.ingest({'__event': 'notification:delete', 'id': '7'});
    expect(service.notifications, isEmpty);
  });

  test('un 401 del backend no rompe: conserva la lista y devuelve false', () async {
    service.ingest({'__event': 'trip:accepted', 'id': 't2'});
    errorBackend = ApiException('Unauthorized', statusCode: 401);
    expect(await service.refresh(), isFalse);
    expect(service.unreadCount, 1);
  });

  test('sin sesión no consulta el backend', () async {
    sesion = false;
    expect(await service.refresh(), isFalse);
    expect(llamadas, 0);
  });

  test('marcar todas leídas limpia el badge y avisa al backend', () async {
    backend = [remota('1'), remota('2'), remota('3', leido: true)];
    await service.refresh();
    service.ingest({'__event': 'trip:accepted', 'id': 't3'});
    expect(service.unreadCount, 3);

    await service.markAllRead();
    expect(service.unreadCount, 0);
    expect(marcadas, unorderedEquals(['1', '2']));
  });

  test('"Conductor asignado" sale de offer:accepted (flujo real) sin duplicar con trip:accepted', () {
    service.ingest({'__event': 'offer:accepted', 'viajeId': '55', 'ofertaId': 'o1'});
    expect(service.unreadCount, 1);
    expect(service.notifications.single['titulo'], 'Conductor asignado');

    service.ingest({'__event': 'trip:accepted', 'id': '55'});
    service.ingest({'__event': 'offer:accepted', 'viajeId': '55', 'ofertaId': 'o1'});
    expect(service.unreadCount, 1);

    service.ingest({'__event': 'offer:accepted', 'viajeId': '56'});
    expect(service.unreadCount, 2);
  });

  test('al conductor no le llega "Conductor asignado" por offer:accepted', () {
    rol = 'conductor';
    service.ingest({'__event': 'offer:accepted', 'viajeId': '57'});
    expect(service.unreadCount, 0);
  });

  test('otro usuario no ve los avisos del anterior', () async {
    service.ingest({'__event': 'trip:accepted', 'id': 't4'});
    expect(service.unreadCount, 1);
    usuario = 'u2';
    expect(service.unreadCount, 0);
    expect(service.notifications, isEmpty);
  });

  testWidgets('la pantalla muestra lo mismo que cuenta la campana', (tester) async {
    backend = [remota('1', fecha: DateTime.now().toIso8601String())];
    service.ingest({'__event': 'trip:cancelled', 'id': 't1', 'canceladoPor': 'admin'});

    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 1'), findsOneWidget);
    expect(find.text('Viaje cancelado'), findsOneWidget);
    expect(find.text('El viaje fue cancelado por soporte'), findsOneWidget);
    expect(service.unreadCount, 2);

    await tester.tap(find.text('Marcar todas leídas'));
    await tester.pumpAndSettle();
    expect(service.unreadCount, 0);
    expect(find.text('Marcar todas leídas'), findsNothing);
  });

  testWidgets('si el backend falla y no hay nada, ofrece reintentar', (tester) async {
    errorBackend = ApiException('Unauthorized', statusCode: 401);
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tus notificaciones'), findsOneWidget);

    errorBackend = null;
    backend = [remota('9', fecha: DateTime.now().toIso8601String())];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 9'), findsOneWidget);
  });
}
