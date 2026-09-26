import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cargaexpress/models/ticket_soporte.dart';
import 'package:cargaexpress/services/api/http_client.dart';
import 'package:cargaexpress/services/api/ticket_service.dart';

import '../helpers/fake_api.dart';

/// Contrato de `/api/support/tickets` (docs/TICKETS_SOPORTE_API.md del
/// backend): crear (JSON o multipart), listar, detalle, escribir, cerrar y
/// los errores `{ error }` con su código HTTP.
void main() {
  Map<String, dynamic> ticketJson({int id = 12, String estado = 'abierto', List<Map<String, dynamic>> mensajes = const []}) => {
        'id': id,
        'categoria': 'pago',
        'asunto': 'Cobro duplicado',
        'descripcion': 'Me cobraron dos veces el mismo viaje del martes.',
        'adjunto': null,
        'estado': estado,
        'zona': 'popayan',
        'viajeId': 123,
        'viaje': {'id': 123, 'estado': 'finalizado', 'origenDireccion': 'Calle 1', 'destinoDireccion': 'Calle 2'},
        'usuario': {'id': 45, 'nombre': 'Ana Pérez', 'rol': 'cliente', 'avatar': null},
        'moderador': estado == 'en_proceso' ? {'id': 7, 'nombre': 'Luis Mod'} : null,
        'totalMensajes': mensajes.length,
        'ultimoMensajeAt': '2026-09-25T20:10:00.000-05:00',
        'resueltoAt': null,
        'cerradoAt': estado == 'cerrado' ? '2026-09-26T10:00:00.000-05:00' : null,
        'createdAt': '2026-09-25T20:10:00.000-05:00',
        'updatedAt': '2026-09-25T20:10:00.000-05:00',
        'mensajes': mensajes,
      };

  Map<String, dynamic> mensajeJson({int id = 90, String rol = 'moderador'}) => {
        'id': id,
        'ticketId': 12,
        'autor': {'id': 7, 'nombre': 'Luis Mod', 'avatar': null},
        'rolAutor': rol,
        'mensaje': 'Hola, ya estamos revisando el cobro.',
        'adjunto': null,
        'createdAt': '2026-09-25T20:15:00.000-05:00',
      };

  /// Error del backend de tickets: `{ error: 'texto' }` (sin `message`).
  http.Response errorTickets(int status, String texto) => jsonResp({'error': texto}, status);

  test('crear (JSON): manda categoria/asunto/descripcion/viajeId y devuelve el ticket 201', () async {
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp(ticketJson(), 201), () async {
      final t = await TicketService.crear(
        categoria: 'pago',
        asunto: 'Cobro duplicado',
        descripcion: 'Me cobraron dos veces el mismo viaje del martes.',
        viajeId: '123',
      );
      expect(t.id, '12');
      expect(t.estado, 'abierto');
      expect(t.viajeId, '123');
      expect(t.viaje?['origenDireccion'], 'Calle 1');
      expect(t.cerrado, isFalse);
      expect(t.mensajes, isEmpty);
    }, log: log);
    final req = log.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/api/support/tickets');
    expect(req.headers['content-type'], startsWith('application/json'));
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['categoria'], 'pago');
    expect(body['asunto'], 'Cobro duplicado');
    expect(body['viajeId'], 123);
    expect(body.containsKey('adjunto'), isFalse);
  });

  test('crear con imagen: multipart con los campos y la foto en `file`', () async {
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp(ticketJson(), 201), () async {
      final t = await TicketService.crear(
        categoria: 'viaje',
        asunto: 'Carga dañada',
        descripcion: 'La caja llegó abierta y con golpes.',
        imagenBytes: Uint8List.fromList([1, 2, 3, 4]),
        imagenNombre: 'foto.jpg',
      );
      expect(t.id, '12');
    }, log: log);
    final req = log.single;
    expect(req.url.path, '/api/support/tickets');
    expect(req.headers['content-type'], startsWith('multipart/form-data'));
    expect(req.headers['authorization'], isNull); // sin sesión en el test: no manda token
    expect(req.body, contains('name="categoria"'));
    expect(req.body, contains('viaje'));
    expect(req.body, contains('name="asunto"'));
    expect(req.body, contains('name="file"; filename="foto.jpg"'));
    expect(req.body, contains('content-type: image/jpeg'));
  });

  test('crear: una imagen mayor a 10 MB se rechaza en local sin llamar al backend', () async {
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp(ticketJson(), 201), () async {
      await expectLater(
        TicketService.crear(
          categoria: 'app',
          asunto: 'Foto enorme',
          descripcion: 'Una imagen muy pesada para probar el límite.',
          imagenBytes: Uint8List(TicketService.maxAdjuntoBytes + 1),
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'ARCHIVO_MUY_GRANDE')),
      );
    }, log: log);
    expect(log, isEmpty);
  });

  test('listar: filtra por estado (coma) y pagina; devuelve tickets y meta', () async {
    final log = <http.Request>[];
    await conApiFalsa(
      (req) => jsonResp({
        'tickets': [ticketJson(id: 12), ticketJson(id: 13, estado: 'en_proceso')],
        'meta': {'total': 2, 'page': 1, 'perPage': 20, 'lastPage': 1},
      }),
      () async {
        final r = await TicketService.listar(estados: TicketSoporte.estadosActivos, page: 1, limit: 20);
        expect(r.tickets.map((t) => t.id), ['12', '13']);
        expect(r.tickets[1].moderadorNombre, 'Luis Mod');
        expect(r.total, 2);
        expect(r.lastPage, 1);
      },
      log: log,
    );
    final req = log.single;
    expect(req.method, 'GET');
    expect(req.url.path, '/api/support/tickets');
    expect(req.url.queryParameters['estado'], 'abierto,en_proceso,resuelto');
    expect(req.url.queryParameters['page'], '1');
    expect(req.url.queryParameters['limit'], '20');
  });

  test('listar cerrados manda estado=cerrado; sin filtro no manda estado', () async {
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp({'tickets': [], 'meta': {'total': 0, 'page': 1, 'perPage': 20, 'lastPage': 1}}), () async {
      final r = await TicketService.listar(estados: const ['cerrado']);
      expect(r.tickets, isEmpty);
      await TicketService.listar();
    }, log: log);
    expect(log[0].url.queryParameters['estado'], 'cerrado');
    expect(log[1].url.queryParameters.containsKey('estado'), isFalse);
  });

  test('detalle: trae el hilo con autor y rolAutor; 404 si no es mío', () async {
    await conApiFalsa((req) {
      if (req.url.path == '/api/support/tickets/12') {
        return jsonResp(ticketJson(estado: 'en_proceso', mensajes: [mensajeJson(), mensajeJson(id: 91, rol: 'usuario')]));
      }
      return errorTickets(404, 'Ticket no encontrado');
    }, () async {
      final t = await TicketService.detalle('12');
      expect(t.estado, 'en_proceso');
      expect(t.mensajes.length, 2);
      expect(t.mensajes.first.nombreParaMostrar, 'Luis Mod');
      expect(t.mensajes.first.esDelUsuario, isFalse);
      expect(t.mensajes.last.esDelUsuario, isTrue);
      expect(t.totalMensajes, 2);

      await expectLater(
        TicketService.detalle('99'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Ticket no encontrado')),
      );
    });
  });

  test('enviarMensaje (JSON): devuelve el mensaje y ticketEstado', () async {
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp({...mensajeJson(id: 95, rol: 'usuario'), 'ticketEstado': 'en_proceso'}, 201), () async {
      final r = await TicketService.enviarMensaje('12', mensaje: 'Gracias, quedo atento.');
      expect(r.mensaje.id, '95');
      expect(r.ticketEstado, 'en_proceso');
    }, log: log);
    final req = log.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/api/support/tickets/12/messages');
    expect(jsonDecode(req.body), {'mensaje': 'Gracias, quedo atento.'});
  });

  test('enviarMensaje con foto va multipart (`mensaje` + `file`)', () async {
    final log = <http.Request>[];
    await conApiFalsa((req) => jsonResp({...mensajeJson(id: 96, rol: 'usuario'), 'ticketEstado': 'abierto'}, 201), () async {
      await TicketService.enviarMensaje('12', mensaje: 'Adjunto el comprobante.', imagenBytes: Uint8List.fromList([9, 9]), imagenNombre: 'c.png');
    }, log: log);
    final req = log.single;
    expect(req.url.path, '/api/support/tickets/12/messages');
    expect(req.headers['content-type'], startsWith('multipart/form-data'));
    expect(req.body, contains('name="mensaje"'));
    expect(req.body, contains('name="file"; filename="c.png"'));
    expect(req.body, contains('content-type: image/png'));
  });

  test('escribir en un ticket cerrado: 422 con el texto del backend', () async {
    await conApiFalsa((req) => errorTickets(422, 'El ticket está cerrado'), () async {
      await expectLater(
        TicketService.enviarMensaje('12', mensaje: 'Hola'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.message, 'message', 'El ticket está cerrado')),
      );
    });
  });

  test('cerrar: POST /close devuelve el ticket cerrado; 429 con mensaje legible', () async {
    final log = <http.Request>[];
    await conApiFalsa((req) {
      if (req.url.path.endsWith('/close')) return jsonResp(ticketJson(estado: 'cerrado'));
      return jsonResp({}, 429);
    }, () async {
      final t = await TicketService.cerrar(12);
      expect(t.cerrado, isTrue);
      expect(t.cerradoAt, isNotNull);

      await expectLater(
        TicketService.crear(categoria: 'otro', asunto: 'Muchos', descripcion: 'Demasiados tickets seguidos.'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.message, 'message', contains('Demasiadas solicitudes'))),
      );
    }, log: log);
    expect(log.first.method, 'POST');
    expect(log.first.url.path, '/api/support/tickets/12/close');
  });

  test('subirAdjunto: multipart a /upload y devuelve adjunto + url firmada', () async {
    final log = <http.Request>[];
    await conApiFalsa(
      (req) => jsonResp({'adjunto': '/storage/uploads/ticket-1.png', 'url': '/storage/uploads/ticket-1.png?exp=1&sig=abc'}),
      () async {
        final r = await TicketService.subirAdjunto(Uint8List.fromList([1]), 'x.png');
        expect(r.adjunto, '/storage/uploads/ticket-1.png');
        expect(r.url, contains('sig=abc'));
      },
      log: log,
    );
    expect(log.single.url.path, '/api/support/tickets/upload');
    expect(log.single.headers['content-type'], startsWith('multipart/form-data'));
  });
}
