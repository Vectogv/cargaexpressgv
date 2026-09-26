import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/contracts/socket_events.dart';
import 'package:cargaexpress/models/ticket_soporte.dart';
import 'package:cargaexpress/screens/cliente/soporte_screen.dart';
import 'package:cargaexpress/screens/conductor/support_screen.dart';
import 'package:cargaexpress/screens/shared/tickets/acceso_tickets_soporte.dart';
import 'package:cargaexpress/screens/shared/tickets/mis_tickets_screen.dart';
import 'package:cargaexpress/screens/shared/tickets/nuevo_ticket_screen.dart';
import 'package:cargaexpress/screens/shared/tickets/ticket_detalle_screen.dart';
import 'package:cargaexpress/screens/shared/tickets/tickets_ui.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

/// Pantallas de tickets de soporte (cliente y conductor): lista con filtros,
/// alta, detalle tipo chat con respaldo periódico y cierre.
void main() {
  Map<String, dynamic> ticketJson({
    int id = 12,
    String estado = 'abierto',
    String asunto = 'Cobro duplicado',
    String categoria = 'pago',
    int totalMensajes = 0,
    List<Map<String, dynamic>>? mensajes,
    Map<String, dynamic>? moderador,
  }) =>
      {
        'id': id,
        'categoria': categoria,
        'asunto': asunto,
        'descripcion': 'Me cobraron dos veces el mismo viaje del martes.',
        'adjunto': null,
        'estado': estado,
        'viajeId': 123,
        'viaje': {'id': 123, 'estado': 'finalizado', 'origenDireccion': 'Calle 1', 'destinoDireccion': 'Calle 2'},
        'moderador': moderador,
        'totalMensajes': mensajes?.length ?? totalMensajes,
        'ultimoMensajeAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'cerradoAt': estado == 'cerrado' ? '2026-09-26T10:00:00.000-05:00' : null,
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        if (mensajes != null) 'mensajes': mensajes,
      };

  Map<String, dynamic> mensajeJson(int id, String texto, {String rol = 'moderador', String? nombre = 'Luis Mod'}) => {
        'id': id,
        'ticketId': 12,
        'autor': {'id': 7, 'nombre': nombre, 'avatar': null},
        'rolAutor': rol,
        'mensaje': texto,
        'adjunto': null,
        'createdAt': DateTime.now().toIso8601String(),
      };

  http.Response listaResp(List<Map<String, dynamic>> tickets) => jsonResp({
        'tickets': tickets,
        'meta': {'total': tickets.length, 'page': 1, 'perPage': 20, 'lastPage': 1},
      });

  Future<void> cerrarPantalla(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await avanzar(tester, 0.5);
  }

  group('Mis tickets', () {
    testWidgets('lista con estado, asunto, categoría y mensajes; filtro Cerrados consulta estado=cerrado', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((req) {
        final estado = req.url.queryParameters['estado'] ?? '';
        if (estado == 'cerrado') return listaResp([ticketJson(id: 3, estado: 'cerrado', asunto: 'Ticket viejo')]);
        return listaResp([
          ticketJson(id: 12, totalMensajes: 3, moderador: {'id': 7, 'nombre': 'Luis Mod'}),
          ticketJson(id: 13, estado: 'en_proceso', asunto: 'No llegó el conductor', categoria: 'viaje'),
        ]);
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: MisTicketsScreen()));
        await avanzar(tester);
        expect(find.text('Cobro duplicado'), findsOneWidget);
        expect(find.text('No llegó el conductor'), findsOneWidget);
        expect(find.byKey(const Key('chip_estado_abierto')), findsOneWidget);
        expect(find.byKey(const Key('chip_estado_en_proceso')), findsOneWidget);
        expect(find.text('Pagos · #12'), findsOneWidget);
        expect(find.text('Viaje · #13'), findsOneWidget);
        expect(find.byKey(const Key('ticket_12_mensajes')), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const Key('ticket_12_mensajes'))).data, '3');
        expect(find.text('Te atiende: Luis Mod'), findsOneWidget);
        expect(find.text('Hace 5 min'), findsWidgets);
        expect(log.last.url.queryParameters['estado'], 'abierto,en_proceso,resuelto');

        await tester.tap(find.byKey(const Key('filtro_cerrados')));
        await avanzar(tester);
        expect(log.last.url.queryParameters['estado'], 'cerrado');
        expect(find.text('Ticket viejo'), findsOneWidget);
        expect(find.text('Cobro duplicado'), findsNothing);
        expect(find.byKey(const Key('chip_estado_cerrado')), findsOneWidget);
        await cerrarPantalla(tester);
      }, log: log);
    });

    testWidgets('estado vacío amable y "Nuevo ticket" abre el formulario', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((req) => listaResp([]), () async {
        await tester.pumpWidget(const MaterialApp(home: MisTicketsScreen()));
        await avanzar(tester);
        expect(find.byKey(const Key('tickets_vacio')), findsOneWidget);
        expect(find.text('Aún no tienes tickets'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_nuevo_ticket')));
        await avanzar(tester);
        expect(find.byType(NuevoTicketScreen), findsOneWidget);
        await cerrarPantalla(tester);
      });
    });

    testWidgets('error -> mensaje y reintentar; un ticket:estado por socket refresca la lista', (tester) async {
      pantallaAlta(tester);
      var falla = true;
      var tickets = [ticketJson(id: 12)];
      await conApiFalsa((req) => falla ? jsonResp({'error': 'Se cayó'}, 500) : listaResp(tickets), () async {
        await tester.pumpWidget(const MaterialApp(home: MisTicketsScreen()));
        await avanzar(tester);
        expect(find.text('No pudimos cargar tus tickets'), findsOneWidget);
        falla = false;
        await tester.tap(find.text('Reintentar'));
        await avanzar(tester);
        expect(find.byKey(const Key('chip_estado_abierto')), findsOneWidget);

        tickets = [ticketJson(id: 12, estado: 'en_proceso', moderador: {'id': 7, 'nombre': 'Luis Mod'})];
        SocketServiceClient.instance.simularEventoParaTest(SocketEvents.ticketEstado, {'id': 12, 'estado': 'en_proceso'});
        await avanzar(tester);
        expect(find.byKey(const Key('chip_estado_en_proceso')), findsOneWidget);
        expect(find.text('Te atiende: Luis Mod'), findsOneWidget);

        // Al tocar un ticket se abre su detalle.
        await tester.tap(find.byKey(const Key('ticket_12')));
        await avanzar(tester);
        expect(find.byType(TicketDetalleScreen), findsOneWidget);
        await cerrarPantalla(tester);
      });
    });
  });

  group('Nuevo ticket', () {
    testWidgets('valida asunto y descripción; al crear va al detalle con el viaje preseleccionado', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((req) {
        if (req.method == 'POST' && req.url.path == '/api/support/tickets') {
          return jsonResp(ticketJson(id: 40, asunto: 'Cobro doble', categoria: 'viaje', mensajes: []), 201);
        }
        if (req.url.path == '/api/support/tickets/40') return jsonResp(ticketJson(id: 40, asunto: 'Cobro doble', mensajes: []));
        return jsonResp({});
      }, () async {
        await tester.pumpWidget(const MaterialApp(
          home: NuevoTicketScreen(viaje: {'_id': '123', 'origen': {'direccion': 'Calle 1'}, 'destino': {'direccion': 'Calle 2'}}),
        ));
        await avanzar(tester);
        // Viene desde un viaje: categoría "Viaje" y el viaje ya asociado.
        expect(find.byKey(const Key('viaje_seleccionado')), findsOneWidget);
        expect(find.text('Viaje #123 · Calle 1 → Calle 2'), findsOneWidget);
        expect(tester.widget<ChoiceChip>(find.byKey(const Key('categoria_viaje'))).selected, isTrue);

        await tester.tap(find.byKey(const Key('btn_enviar_ticket')));
        await avanzar(tester, 0.5);
        expect(find.textContaining('Escribe un asunto'), findsOneWidget);
        expect(log.where((r) => r.method == 'POST'), isEmpty);

        await tester.enterText(find.byKey(const Key('campo_asunto')), 'Cobro doble');
        await tester.enterText(find.byKey(const Key('campo_descripcion')), 'corto');
        await tester.tap(find.byKey(const Key('btn_enviar_ticket')));
        await avanzar(tester, 0.5);
        expect(find.textContaining('un poco más de detalle'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('campo_descripcion')), 'Me cobraron dos veces el mismo viaje.');
        await tester.tap(find.byKey(const Key('btn_enviar_ticket')));
        await avanzar(tester);
        final post = log.firstWhere((r) => r.method == 'POST');
        final body = jsonDecode(post.body) as Map<String, dynamic>;
        expect(body['categoria'], 'viaje');
        expect(body['viajeId'], 123);
        expect(body['asunto'], 'Cobro doble');
        expect(find.byType(TicketDetalleScreen), findsOneWidget);
        expect(find.text('Ticket #40'), findsOneWidget);
        await cerrarPantalla(tester);
      }, log: log);
    });

    testWidgets('429 (demasiados tickets) muestra el error del backend y se queda en el formulario', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((req) => jsonResp({'error': 'Demasiadas solicitudes, espera un minuto.'}, 429), () async {
        await tester.pumpWidget(const MaterialApp(home: NuevoTicketScreen(categoriaInicial: 'pago', asuntoInicial: 'Ya pagué')));
        await avanzar(tester);
        expect(tester.widget<ChoiceChip>(find.byKey(const Key('categoria_pago'))).selected, isTrue);
        await tester.enterText(find.byKey(const Key('campo_descripcion')), 'Pagué ayer y sigo suspendido.');
        await tester.tap(find.byKey(const Key('btn_enviar_ticket')));
        await avanzar(tester);
        expect(find.text('Demasiadas solicitudes, espera un minuto.'), findsOneWidget);
        expect(find.byType(NuevoTicketScreen), findsOneWidget);
        await cerrarPantalla(tester);
      });
    });
  });

  group('Detalle del ticket', () {
    testWidgets('hilo: soporte a la izquierda con su nombre; escribir agrega el mensaje; el respaldo cada 5 s trae lo nuevo sin socket', (tester) async {
      pantallaAlta(tester);
      var mensajes = [mensajeJson(90, 'Hola, ya estamos revisando el cobro.')];
      var detalles = 0;
      final log = <http.Request>[];
      await conApiFalsa((req) {
        if (req.method == 'GET' && req.url.path == '/api/support/tickets/12') {
          detalles++;
          return jsonResp(ticketJson(estado: 'en_proceso', moderador: {'id': 7, 'nombre': 'Luis Mod'}, mensajes: mensajes));
        }
        if (req.method == 'POST' && req.url.path == '/api/support/tickets/12/messages') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final nuevo = mensajeJson(91, body['mensaje'] as String, rol: 'usuario', nombre: 'Ana');
          mensajes = [...mensajes, nuevo];
          return jsonResp({...nuevo, 'ticketEstado': 'en_proceso'}, 201);
        }
        return jsonResp({});
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: TicketDetalleScreen(ticketId: '12')));
        await avanzar(tester);
        expect(find.text('Ticket #12'), findsOneWidget);
        expect(find.text('Cobro duplicado'), findsOneWidget);
        expect(find.text('Hola, ya estamos revisando el cobro.'), findsOneWidget);
        expect(find.text('Luis Mod'), findsOneWidget); // nombre sobre la burbuja del staff
        expect(find.text('Te atiende: Luis Mod'), findsOneWidget);
        expect(find.byKey(const Key('btn_cerrar_ticket')), findsOneWidget);
        final antes = detalles;

        // Escribir: aparece a la derecha y se manda por POST.
        await tester.enterText(find.byKey(const Key('campo_mensaje')), 'Gracias, quedo atento.');
        await tester.tap(find.byKey(const Key('btn_enviar_mensaje')));
        await avanzar(tester);
        expect(find.text('Gracias, quedo atento.'), findsOneWidget);
        expect(log.any((r) => r.method == 'POST' && r.url.path.endsWith('/messages')), isTrue);

        // Sin socket: el staff responde y el sondeo de respaldo (5 s) lo trae.
        mensajes = [...mensajes, mensajeJson(92, 'Listo, te devolvimos el cobro.')];
        expect(find.text('Listo, te devolvimos el cobro.'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        await avanzar(tester);
        expect(detalles, greaterThan(antes));
        expect(find.text('Listo, te devolvimos el cobro.'), findsOneWidget);
        await cerrarPantalla(tester);
      }, log: log);
    });

    testWidgets('con el teclado abierto la caja y el botón de enviar quedan encima del teclado', (tester) async {
      pantallaAlta(tester);
      // Teclado de 900 px físicos = 300 dp (pantallaAlta: 960 dp de alto).
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      final mensajes = [for (var i = 0; i < 12; i++) mensajeJson(100 + i, 'Mensaje largo número $i para llenar el hilo.')];
      await conApiFalsa((req) => jsonResp(ticketJson(mensajes: mensajes)), () async {
        await tester.pumpWidget(const MaterialApp(home: TicketDetalleScreen(ticketId: '12')));
        await avanzar(tester);
        final alto = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final enviar = tester.getBottomLeft(find.byKey(const Key('btn_enviar_mensaje'))).dy;
        final campo = tester.getBottomLeft(find.byKey(const Key('campo_mensaje'))).dy;
        expect(enviar, lessThanOrEqualTo(alto - 300));
        expect(campo, lessThanOrEqualTo(alto - 300));
        // El botón sigue siendo tocable (no está tapado ni fuera de la pantalla).
        await tester.enterText(find.byKey(const Key('campo_mensaje')), 'Hola');
        await tester.tap(find.byKey(const Key('btn_enviar_mensaje')));
        await avanzar(tester);
        await cerrarPantalla(tester);
      });
    });

    testWidgets('ticket:mensaje por socket agrega el mensaje al instante y al reconectar se vuelve a consultar', (tester) async {
      pantallaAlta(tester);
      var detalles = 0;
      await conApiFalsa((req) {
        if (req.url.path == '/api/support/tickets/12') {
          detalles++;
          return jsonResp(ticketJson(mensajes: []));
        }
        return jsonResp({});
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: TicketDetalleScreen(ticketId: '12')));
        await avanzar(tester);
        expect(find.byKey(const Key('ticket_sin_mensajes')), findsOneWidget);
        final antes = detalles;

        SocketServiceClient.instance.simularEventoParaTest(SocketEvents.ticketMensaje, {
          'ticketId': 12,
          'estado': 'en_proceso',
          'mensaje': mensajeJson(93, 'Te escribo por el socket.'),
        });
        await avanzar(tester, 0.5);
        expect(find.text('Te escribo por el socket.'), findsOneWidget);
        expect(find.byKey(const Key('chip_estado_en_proceso')), findsOneWidget);
        // Otro ticket no afecta a este.
        SocketServiceClient.instance.simularEventoParaTest(SocketEvents.ticketMensaje, {
          'ticketId': 99,
          'estado': 'en_proceso',
          'mensaje': mensajeJson(94, 'De otro ticket.'),
        });
        await avanzar(tester, 0.5);
        expect(find.text('De otro ticket.'), findsNothing);

        SocketServiceClient.instance.simularConexionParaTest(true);
        await avanzar(tester, 0.5);
        expect(detalles, greaterThan(antes));
        await cerrarPantalla(tester);
      });
    });

    testWidgets('cerrado: sin caja de texto ni "Cerrar ticket", con aviso y botón para abrir otro', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((req) => jsonResp(ticketJson(estado: 'cerrado', mensajes: [mensajeJson(90, 'Resuelto.')])), () async {
        await tester.pumpWidget(const MaterialApp(home: TicketDetalleScreen(ticketId: '12')));
        await avanzar(tester);
        expect(find.byKey(const Key('aviso_ticket_cerrado')), findsOneWidget);
        expect(find.byKey(const Key('campo_mensaje')), findsNothing);
        expect(find.byKey(const Key('btn_enviar_mensaje')), findsNothing);
        expect(find.byKey(const Key('btn_cerrar_ticket')), findsNothing);
        expect(find.byKey(const Key('btn_nuevo_ticket_desde_cerrado')), findsOneWidget);
        await cerrarPantalla(tester);
      });
    });

    testWidgets('si el staff lo cerró mientras escribía: 422, se avisa y la pantalla pasa a cerrado', (tester) async {
      pantallaAlta(tester);
      var cerrado = false;
      await conApiFalsa((req) {
        if (req.method == 'POST') {
          cerrado = true;
          return jsonResp({'error': 'El ticket está cerrado'}, 422);
        }
        return jsonResp(ticketJson(estado: cerrado ? 'cerrado' : 'abierto', mensajes: []));
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: TicketDetalleScreen(ticketId: '12')));
        await avanzar(tester);
        await tester.enterText(find.byKey(const Key('campo_mensaje')), 'Hola?');
        await tester.tap(find.byKey(const Key('btn_enviar_mensaje')));
        await avanzar(tester);
        expect(find.textContaining('El ticket está cerrado'), findsWidgets);
        expect(find.byKey(const Key('aviso_ticket_cerrado')), findsOneWidget);
        expect(find.byKey(const Key('campo_mensaje')), findsNothing);
        await cerrarPantalla(tester);
      });
    });

    testWidgets('"Cerrar ticket" pide confirmación y llama a /close', (tester) async {
      pantallaAlta(tester);
      final log = <http.Request>[];
      await conApiFalsa((req) {
        if (req.url.path.endsWith('/close')) return jsonResp(ticketJson(estado: 'cerrado', mensajes: []));
        return jsonResp(ticketJson(mensajes: []));
      }, () async {
        await tester.pumpWidget(const MaterialApp(home: TicketDetalleScreen(ticketId: '12')));
        await avanzar(tester);
        await tester.tap(find.byKey(const Key('btn_cerrar_ticket')));
        await avanzar(tester, 0.5);
        expect(find.text('Volver'), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_confirmar_cerrar_ticket')));
        await avanzar(tester);
        expect(log.any((r) => r.method == 'POST' && r.url.path == '/api/support/tickets/12/close'), isTrue);
        expect(find.byKey(const Key('aviso_ticket_cerrado')), findsOneWidget);
        expect(find.byKey(const Key('campo_mensaje')), findsNothing);
        await cerrarPantalla(tester);
      }, log: log);
    });

    testWidgets('404 (ticket ajeno): error con reintentar', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((req) => jsonResp({'error': 'Ticket no encontrado'}, 404), () async {
        await tester.pumpWidget(const MaterialApp(home: TicketDetalleScreen(ticketId: '77')));
        await avanzar(tester);
        expect(find.text('No pudimos cargar el ticket'), findsOneWidget);
        expect(find.text('Ticket no encontrado'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        await cerrarPantalla(tester);
      });
    });
  });

  group('Accesos a soporte', () {
    testWidgets('sin sesión la tarjeta explica que debe iniciar sesión; con sesión ofrece Mis tickets y Nuevo ticket', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AccesoTicketsSoporte(conSesion: false))));
      await tester.pump();
      expect(find.byKey(const Key('tickets_sin_sesion')), findsOneWidget);
      expect(find.byKey(const Key('btn_mis_tickets')), findsNothing);

      await conApiFalsa((req) => listaResp([]), () async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AccesoTicketsSoporte(conSesion: true))));
        await tester.pump();
        expect(find.byKey(const Key('tickets_sin_sesion')), findsNothing);
        await tester.tap(find.byKey(const Key('btn_mis_tickets')));
        await avanzar(tester);
        expect(find.byType(MisTicketsScreen), findsOneWidget);
        await cerrarPantalla(tester);
      });
    });

    testWidgets('las pantallas de Soporte del cliente y del conductor muestran la tarjeta de tickets', (tester) async {
      pantallaAlta(tester);
      await conApiFalsa((req) => jsonResp([]), () async {
        await tester.pumpWidget(const MaterialApp(home: SoporteScreen()));
        await avanzar(tester);
        expect(find.byType(AccesoTicketsSoporte), findsOneWidget);
        expect(find.text('No tienes conversaciones de soporte'), findsOneWidget);

        await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
        await avanzar(tester);
        expect(find.byType(AccesoTicketsSoporte), findsOneWidget);
        await cerrarPantalla(tester);
      });
    });
  });

  test('tiempos relativos y resumen de viaje', () {
    final ahora = DateTime(2026, 9, 26, 12, 0);
    expect(tiempoRelativoTicket(ahora.subtract(const Duration(seconds: 20)), ahora: ahora), 'Ahora');
    expect(tiempoRelativoTicket(ahora.subtract(const Duration(minutes: 7)), ahora: ahora), 'Hace 7 min');
    expect(tiempoRelativoTicket(ahora.subtract(const Duration(hours: 3)), ahora: ahora), 'Hace 3 h');
    expect(tiempoRelativoTicket(ahora.subtract(const Duration(days: 1)), ahora: ahora), 'Ayer');
    expect(tiempoRelativoTicket(ahora.subtract(const Duration(days: 10)), ahora: ahora), '16/09/2026');
    expect(horaMensajeTicket(DateTime(2026, 9, 26, 9, 5), ahora: ahora), '09:05');
    expect(horaMensajeTicket(DateTime(2026, 9, 20, 9, 5), ahora: ahora), '20/09 09:05');
    expect(resumenViajeTicket({'id': 5, 'origenDireccion': 'A', 'destinoDireccion': 'B'}), 'Viaje #5 · A → B');
    expect(resumenViajeTicket({'_id': '6'}), 'Viaje #6');
    expect(TicketSoporte.etiquetaEstado('en_proceso'), 'En proceso');
  });
}
