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
    service.markAllRemoteRead = () async => marcadas.add('todas');
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

  test(
      'viaje cancelado por el sistema (BusquedaTimeoutService) usa el aviso '
      'y tipo busqueda_sin_conductor, no el genérico "Viaje cancelado"', () {
    service.ingest({
      '__event': 'trip:cancelled',
      'id': 't2',
      'canceladoPor': 'sistema',
      'motivo': 'Sin conductores disponibles',
    });
    expect(service.unreadCount, 1);
    final n = service.notifications.single;
    expect(n['tipo'], 'busqueda_sin_conductor');
    expect(n['titulo'], 'No encontramos conductor');
    expect(n['mensaje'], contains('15 minutos'));
    expect(n['mensaje'], contains('No se te cobró nada'));
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
    // Una sola llamada a PUT /api/notifications/read-all, no una por aviso.
    expect(marcadas, ['todas']);
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

  test('tocar un push de ticket (ticket_mensaje / ticket_estado) abre el detalle del ticket', () {
    final abiertos = <String>[];
    service.abrirTicket = abiertos.add;
    addTearDown(() => service.abrirTicket = null);

    // Los valores de `data` del FCM son strings.
    service.manejarToqueDePush(
      {'tipo': 'ticket_mensaje', 'ticketId': '12', 'mensajeId': '90', 'estado': 'en_proceso'},
      titulo: 'Respuesta a tu ticket #12',
      cuerpo: 'Hola, ya estamos revisando el cobro.',
    );
    service.manejarToqueDePush({'tipo': 'ticket_estado', 'ticketId': '13', 'estado': 'resuelto'});
    expect(abiertos, ['12', '13']);
    // El aviso queda en la lista con su ticketId para abrirlo desde ahí.
    final n = service.notifications.firstWhere((n) => n['titulo'] == 'Respuesta a tu ticket #12');
    expect(n['tipo'], 'ticket_mensaje');
    expect(n['ticketId'], '12');

    // Otros push no abren nada; sin sesión tampoco.
    service.manejarToqueDePush({'type': 'new_trip', 'tripId': '5'});
    sesion = false;
    service.manejarToqueDePush({'tipo': 'ticket_mensaje', 'ticketId': '14'});
    expect(abiertos, ['12', '13']);
  });

  test('tocar un push de conversación con moderación abre la conversación', () {
    final abiertas = <String>[];
    service.abrirConversacion = abiertas.add;
    addTearDown(() => service.abrirConversacion = null);

    service.manejarToqueDePush({'tipo': 'conversacion_mensaje', 'conversacionId': '8'}, titulo: 'Moderación CargaExpress');
    service.manejarToqueDePush({'tipo': 'conversacion_mensaje'});
    sesion = false;
    service.manejarToqueDePush({'tipo': 'conversacion_mensaje', 'conversacionId': '9'});
    expect(abiertas, ['8']);
  });

  test('tocar un push de viaje (estado / cancelado / disputa) abre el viaje', () {
    final abiertos = <String>[];
    service.abrirViaje = abiertos.add;
    addTearDown(() => service.abrirViaje = null);

    service.manejarToqueDePush({'tipo': 'viaje_estado', 'viajeId': '51'}, titulo: 'El conductor llegó');
    service.manejarToqueDePush({'tipo': 'viaje_cancelado', 'viajeId': '52'});
    service.manejarToqueDePush({'tipo': 'disputa_resuelta', 'viajeId': '53'});
    service.manejarToqueDePush({'tipo': 'reserva', 'viajeId': '56'}, titulo: 'Reserva asignada');
    expect(abiertos, ['51', '52', '53', '56']);

    // Sin viajeId, de otro tipo o sin sesión no abre nada.
    service.manejarToqueDePush({'tipo': 'viaje_estado'});
    service.manejarToqueDePush({'tipo': 'ticket_estado', 'viajeId': '54'});
    sesion = false;
    service.manejarToqueDePush({'tipo': 'viaje_estado', 'viajeId': '55'});
    expect(abiertos, ['51', '52', '53', '56']);
  });

  test('tocar un push "Faltan documentos" del moderador abre Documentos', () {
    var abiertos = 0;
    service.abrirDocumentos = () => abiertos++;
    addTearDown(() => service.abrirDocumentos = null);

    service.manejarToqueDePush({'tipo': 'documentos_faltantes'}, titulo: 'Faltan documentos');
    expect(abiertos, 1);
    service.manejarToqueDePush({'tipo': 'viaje_estado'});
    sesion = false;
    service.manejarToqueDePush({'tipo': 'documentos_faltantes'});
    expect(abiertos, 1);
  });

  test('normalizar saca el ticketId de la raíz o de data/datos (notification:new)', () {
    expect(NotificationService.normalizar({'id': 'n1', 'tipo': 'ticket_estado', 'ticketId': 12})['ticketId'], '12');
    expect(NotificationService.normalizar({'id': 'n2', 'tipo': 'ticket_mensaje', 'data': {'ticketId': '15'}})['ticketId'], '15');
    expect(NotificationService.normalizar({'id': 'n3', 'tipo': 'ticket_mensaje', 'datos': {'ticketId': 16}})['ticketId'], '16');
    expect(NotificationService.normalizar({'id': 'n4', 'tipo': 'mensaje'}).containsKey('ticketId'), isFalse);
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

    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pumpAndSettle();
    expect(service.unreadCount, 0);
    expect(marcadas, ['todas']); // una sola llamada a read-all
    expect(find.text('Marcar todas como leídas'), findsNothing);
  });

  testWidgets('agrupa por día: Hoy, Ayer y fecha', (tester) async {
    final ahora = DateTime.now();
    backend = [
      remota('1', fecha: ahora.toIso8601String()),
      remota('2', fecha: ahora.subtract(const Duration(days: 1)).toIso8601String()),
      remota('3', fecha: ahora.subtract(const Duration(days: 5)).toIso8601String()),
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    final viejo = ahora.subtract(const Duration(days: 5));
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('${viejo.day}/${viejo.month}/${viejo.year}'), findsOneWidget);
  });

  testWidgets('sin no leídas no hay botón; tocar una la marca leída y abre su viaje', (tester) async {
    final abiertos = <String>[];
    service.abrirViaje = abiertos.add;
    addTearDown(() => service.abrirViaje = null);
    backend = [
      {...remota('1', fecha: DateTime.now().toIso8601String()), 'viajeId': '77'},
      remota('2', leido: true, fecha: DateTime.now().toIso8601String()),
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Marcar todas como leídas'), findsOneWidget);

    await tester.tap(find.text('Aviso 1'));
    await tester.pumpAndSettle();
    expect(marcadas, ['1']);
    expect(abiertos, ['77']);
    expect(service.unreadCount, 0);
    expect(find.text('Marcar todas como leídas'), findsNothing);
  });

  testWidgets('sin desbordes a 360 px con letra 1.3', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend = [remota('1', fecha: DateTime.now().toIso8601String())];
    await tester.pumpWidget(MaterialApp(
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)), child: w!),
      home: const NotificationsScreen(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('un push repetido no se duplica ni con su aviso guardado', () {
    service.ingest({'__event': 'x', '__source': 'fcm', 'title': 'Hola', 'body': 'Mundo'});
    service.ingest({'__event': 'x', '__source': 'fcm', 'title': 'Hola', 'body': 'Mundo'});
    service.ingest({'__event': 'x', '__source': 'fcm', '__tap': true, 'title': 'Hola', 'body': 'Mundo'});
    expect(service.notifications.length, 1);
    service.ingest({'__event': 'notification:new', 'id': '9', 'titulo': 'Hola', 'mensaje': 'Mundo'});
    expect(service.notifications.length, 1);
    expect(service.notifications.first['id'], '9');
  });

  testWidgets('la notificación disputa_resuelta tiene icono de disputa (disputa_cierre ya no existe: llega como viaje_estado)', (tester) async {
    backend = [
      {...remota('d1', fecha: DateTime.now().toIso8601String()), 'tipo': 'disputa_resuelta', 'viajeId': '5'},
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.gavel_rounded), findsOneWidget);
  });

  testWidgets('la notificación suspension_por_pago tiene su propio icono', (tester) async {
    backend = [
      {...remota('s1', fecha: DateTime.now().toIso8601String()), 'tipo': 'suspension_por_pago'},
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.money_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
  });

  testWidgets(
      'la notificación busqueda_sin_conductor (BusquedaTimeoutService) tiene su propio icono',
      (tester) async {
    backend = [
      {...remota('b1', fecha: DateTime.now().toIso8601String()), 'tipo': 'busqueda_sin_conductor'},
    ];
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
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
