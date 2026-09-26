import 'dart:typed_data';

import '../../models/ticket_soporte.dart';
import 'http_client.dart';

/// Tickets de soporte del cliente/conductor (`/api/support/tickets`, ver
/// `docs/TICKETS_SOPORTE_API.md` del backend).
///
/// Errores: el backend responde `{ error }` y [HttpClient] lo convierte en
/// [ApiException] con el `statusCode` (404 ticket ajeno, 422 validación o
/// ticket cerrado, 429 demasiadas solicitudes).
class TicketService {
  /// Máximo del backend para las imágenes de los tickets (jpg, png, webp, heic).
  static const int maxAdjuntoBytes = 10 * 1024 * 1024;

  /// Crea un ticket. Con [imagenBytes] se envía multipart (imagen en `file`);
  /// si no, JSON (con [adjunto] ya subido por [subirAdjunto], opcional).
  static Future<TicketSoporte> crear({
    required String categoria,
    required String asunto,
    required String descripcion,
    dynamic viajeId,
    String? adjunto,
    String? zona,
    Uint8List? imagenBytes,
    String? imagenNombre,
  }) async {
    final campos = <String, String>{
      'categoria': categoria,
      'asunto': asunto,
      'descripcion': descripcion,
      if (viajeId != null) 'viajeId': viajeId.toString(),
      if (zona != null && zona.isNotEmpty) 'zona': zona,
    };
    final Map<String, dynamic> data;
    if (imagenBytes != null) {
      data = await HttpClient.uploadFile(
        '/api/support/tickets',
        bytes: imagenBytes,
        filename: imagenNombre ?? 'ticket_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fieldName: 'file',
        fields: campos,
        auth: true,
        maxBytes: maxAdjuntoBytes,
      );
    } else {
      data = await HttpClient.post('/api/support/tickets', body: {
        'categoria': categoria,
        'asunto': asunto,
        'descripcion': descripcion,
        if (viajeId != null) 'viajeId': viajeId is num ? viajeId : (int.tryParse(viajeId.toString()) ?? viajeId),
        if (adjunto != null && adjunto.isNotEmpty) 'adjunto': adjunto,
        if (zona != null && zona.isNotEmpty) 'zona': zona,
      }, auth: true);
    }
    return TicketSoporte.fromJson(data);
  }

  /// Sube una imagen aparte: `adjunto` (ruta para crear/escribir) y `url`
  /// (firmada, para mostrarla).
  static Future<({String adjunto, String url})> subirAdjunto(Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile(
      '/api/support/tickets/upload',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      auth: true,
      maxBytes: maxAdjuntoBytes,
    );
    final adjunto = data['adjunto']?.toString() ?? '';
    return (adjunto: adjunto, url: data['url']?.toString() ?? adjunto);
  }

  /// Mis tickets, última actividad primero. [estados] filtra (`abierto`,
  /// `en_proceso`, `resuelto`, `cerrado`); vacío o null trae todos.
  static Future<({List<TicketSoporte> tickets, int total, int page, int lastPage})> listar({
    List<String>? estados,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String>[
      if (estados != null && estados.isNotEmpty) 'estado=${estados.join(',')}',
      'page=$page',
      'limit=$limit',
    ].join('&');
    final data = await HttpClient.get('/api/support/tickets?$query', auth: true);
    final lista = data['tickets'];
    final meta = data['meta'];
    int entero(dynamic v, int porDefecto) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? porDefecto);
    final tickets = lista is List
        ? lista.whereType<Map>().map((t) => TicketSoporte.fromJson(Map<String, dynamic>.from(t))).toList()
        : <TicketSoporte>[];
    return (
      tickets: tickets,
      total: entero(meta is Map ? meta['total'] : null, tickets.length),
      page: entero(meta is Map ? meta['page'] : null, page),
      lastPage: entero(meta is Map ? meta['lastPage'] : null, 1),
    );
  }

  /// Detalle con el hilo `mensajes` (ascendente). 404 si no es del usuario.
  static Future<TicketSoporte> detalle(dynamic id) async {
    final data = await HttpClient.get('/api/support/tickets/$id', auth: true);
    return TicketSoporte.fromJson(data);
  }

  /// Escribe en el hilo. Con [imagenBytes] va multipart (`mensaje` + `file`).
  /// Devuelve el mensaje guardado y el estado del ticket tras escribir (un
  /// ticket `resuelto` vuelve a `en_proceso`). 422 si el ticket está cerrado.
  static Future<({MensajeTicket mensaje, String? ticketEstado})> enviarMensaje(
    dynamic id, {
    required String mensaje,
    String? adjunto,
    Uint8List? imagenBytes,
    String? imagenNombre,
  }) async {
    final Map<String, dynamic> data;
    if (imagenBytes != null) {
      data = await HttpClient.uploadFile(
        '/api/support/tickets/$id/messages',
        bytes: imagenBytes,
        filename: imagenNombre ?? 'ticket_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fieldName: 'file',
        fields: {'mensaje': mensaje},
        auth: true,
        maxBytes: maxAdjuntoBytes,
      );
    } else {
      data = await HttpClient.post('/api/support/tickets/$id/messages', body: {
        'mensaje': mensaje,
        if (adjunto != null && adjunto.isNotEmpty) 'adjunto': adjunto,
      }, auth: true);
    }
    return (
      mensaje: MensajeTicket.fromJson(data),
      ticketEstado: data['ticketEstado']?.toString(),
    );
  }

  /// Cierra mi ticket. 422 si ya estaba cerrado.
  static Future<TicketSoporte> cerrar(dynamic id) async {
    final data = await HttpClient.post('/api/support/tickets/$id/close', auth: true);
    return TicketSoporte.fromJson(data);
  }
}
