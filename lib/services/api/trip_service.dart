import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'http_client.dart';

/// Métodos con `idempotencyKey`: las pantallas pueden generar una clave por
/// acción del usuario (`HttpClient.newIdempotencyKey()`) y reutilizarla en
/// reintentos para que el backend no duplique la operación. Sin clave se
/// genera una nueva por llamada.
class TripService {
  static Future<Map<String, dynamic>> requestTrip(Map<String, dynamic> data, {String? idempotencyKey}) async {
    // El contrato del backend exige X-Idempotency-Key para prevenir duplicados.
    return HttpClient.post('/api/trips/request', body: data, auth: true, idempotent: true, idempotencyKey: idempotencyKey);
  }

  static Future<Map<String, dynamic>?> getActiveTrip() async {
    try {
      return await HttpClient.get('/api/trips/active', auth: true);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getTripHistory({int page = 1, int limit = 20, String? estado}) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (estado != null) params['estado'] = estado;
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final data = await HttpClient.get('/api/trips/history?$query', auth: true);
    return (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  static Future<Map<String, dynamic>> getTripDetail(dynamic id) async {
    return HttpClient.get('/api/trips/$id', auth: true);
  }

  /// Vehículos disponibles cerca del origen mientras se busca conductor.
  /// Respuesta: {radioKm, conductores: [{lat, lng, tipoVehiculo, distanciaKm}]}.
  static Future<List<Map<String, dynamic>>> getNearbyDrivers(dynamic tripId) async {
    final data = await HttpClient.get('/api/trips/$tripId/nearby-drivers', auth: true);
    return (data['conductores'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Sin `lat`/`lng` el backend usa la última ubicación guardada del
  /// conductor (trip_controller.nearby).
  static Future<List<Map<String, dynamic>>> getNearbyTrips(double? lat, double? lng, {double radio = 5}) async {
    final params = [
      if (lat != null && lng != null) 'lat=$lat&lng=$lng',
      'radio=$radio',
    ].join('&');
    // Tolerar ambos contratos: array plano `[...]` (api_spec) o `{data: [...]}` (mock/backend).
    final list = await HttpClient.getList('/api/trips/nearby?$params', auth: true);
    return list.whereType<Map<String, dynamic>>().toList();
  }

  static Future<void> startTrip(dynamic id) async {
    await HttpClient.post('/api/trips/$id/start-trip', auth: true);
  }

  static Future<void> confirmArrival(dynamic id) async {
    await HttpClient.post('/api/trips/$id/confirm-arrival', auth: true);
  }

  static Future<Map<String, dynamic>> reserveTrip(Map<String, dynamic> data, {String? idempotencyKey}) async {
    return HttpClient.post('/api/trips/reserve', body: data, auth: true, idempotent: true, idempotencyKey: idempotencyKey);
  }

  static Future<List<Map<String, dynamic>>> getReservations({int page = 1, int limit = 20, String? estado}) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (estado != null) params['estado'] = estado;
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final data = await HttpClient.get('/api/trips/reservations?$query', auth: true);
    return (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  static Future<void> confirmPickup(dynamic id) async {
    await HttpClient.post('/api/trips/$id/confirm-pickup', auth: true);
  }

  static Future<Map<String, dynamic>> disputeAppeal(dynamic id, {required String motivo, String? descripcion}) async {
    return HttpClient.post('/api/trips/$id/dispute/appeal', body: {'motivo': motivo, 'descripcion': descripcion}, auth: true);
  }

  static Future<void> completeTrip(dynamic id, {num? montoFinal, String? justificacion, String? pin, String? idempotencyKey}) async {
    final body = <String, dynamic>{};
    if (montoFinal != null) body['montoFinal'] = montoFinal;
    if (justificacion != null) body['justificacion'] = justificacion;
    if (pin != null) body['pin'] = pin;
    await HttpClient.post('/api/trips/$id/complete', body: body, auth: true, idempotent: true, idempotencyKey: idempotencyKey);
  }

  static Future<void> finalizeTrip(dynamic id, {num? montoFinal, String? justificacion, String? pin, String? idempotencyKey}) async {
    final body = <String, dynamic>{};
    if (montoFinal != null) body['montoFinal'] = montoFinal;
    if (justificacion != null) body['justificacion'] = justificacion;
    if (pin != null) body['pin'] = pin;
    await HttpClient.post('/api/trips/$id/finalize', body: body, auth: true, idempotent: true, idempotencyKey: idempotencyKey);
  }

  /// Devuelve la respuesta del backend: al cancelar una reserva asignada el
  /// conductor recibe `reabierta` y `penalizado` (-0,5 solo si faltan < 24 h).
  static Future<Map<String, dynamic>> cancelTrip(dynamic id, {String? motivo, String? justificacion}) async {
    final body = <String, dynamic>{};
    if (motivo != null) body['motivo'] = motivo;
    if (justificacion != null) body['justificacion'] = justificacion;
    return HttpClient.post('/api/trips/$id/cancel', body: body, auth: true);
  }

  /// El conductor pide más tiempo en una reserva (una sola vez por reserva).
  static Future<Map<String, dynamic>> requestMorePlazo(dynamic id, int minutos) async {
    return HttpClient.post('/api/trips/$id/plazo', body: {'minutos': minutos}, auth: true);
  }

  /// El cliente acepta o rechaza el plazo que pidió el conductor.
  static Future<Map<String, dynamic>> responderPlazo(dynamic id, {required bool aceptar}) async {
    return HttpClient.post('/api/trips/$id/plazo/responder', body: {'aceptar': aceptar}, auth: true);
  }

  static Future<void> requestCancellation(dynamic id, {String? motivo, String? justificacion}) async {
    final body = <String, dynamic>{};
    if (motivo != null) body['motivo'] = motivo;
    if (justificacion != null) body['justificacion'] = justificacion;
    await HttpClient.post('/api/trips/$id/request-cancellation', body: body, auth: true);
  }

  static Future<Map<String, dynamic>> confirmClose(dynamic id, {required bool confirmar, String? motivo, String? idempotencyKey}) async {
    return HttpClient.post('/api/trips/$id/confirm-close', body: {'confirmar': confirmar, if (motivo != null) 'motivo': motivo}, auth: true, idempotencyKey: idempotencyKey);
  }

  static Future<Map<String, dynamic>> disputeTrip(dynamic id, {required String motivo, String? descripcion}) async {
    return HttpClient.post('/api/trips/$id/dispute', body: {'motivo': motivo, 'descripcion': descripcion}, auth: true);
  }

  static const String prefViajesCalificados = 'viajes_calificados';

  /// Un 400 "Ya calificaste este viaje" cuenta como éxito: la calificación
  /// existe. El detalle del backend no informa si ya se calificó, así que se
  /// recuerda en el teléfono ([yaCalificado]).
  static Future<void> rateTrip(dynamic id, int puntaje, {String? comentario}) async {
    try {
      await HttpClient.post('/api/trips/$id/rate', body: {'puntaje': puntaje, 'comentario': comentario}, auth: true);
    } on ApiException catch (e) {
      if (e.statusCode != 400 || !e.message.toLowerCase().contains('ya calificaste')) rethrow;
    }
    await _marcarCalificado(id);
  }

  static Future<bool> yaCalificado(dynamic id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(prefViajesCalificados) ?? const <String>[]).contains(id.toString());
    } catch (_) {
      return false;
    }
  }

  static Future<void> _marcarCalificado(dynamic id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = List<String>.from(prefs.getStringList(prefViajesCalificados) ?? const <String>[]);
      if (lista.contains(id.toString())) return;
      lista.add(id.toString());
      if (lista.length > 200) lista.removeRange(0, lista.length - 200);
      await prefs.setStringList(prefViajesCalificados, lista);
    } catch (_) {}
  }

  static Future<String> deliveryPhoto(dynamic tripId, Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/trips/$tripId/delivery-photo', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['fotoEntrega'] as String? ?? data['url'] as String? ?? '';
  }

  /// Foto de la carga al recogerla (evidencia, no bloquea el flujo). El
  /// backend exige estar en 'conductor_llegada' o 'en_curso'.
  static Future<String> pickupPhoto(dynamic tripId, Uint8List bytes, String filename) async {
    final data = await HttpClient.uploadFile('/api/trips/$tripId/pickup-photo', bytes: bytes, filename: filename, fieldName: 'file', auth: true);
    return data['fotoRecogida'] as String? ?? data['url'] as String? ?? '';
  }

  // La subida de fotos de disputa es SOLO de cliente: POST /api/trips/:id/dispute/support
  static Future<String> disputePhoto(dynamic tripId, Uint8List bytes, String filename) async {
    // El backend acepta hasta 10 MB (heic/pdf incluidos) para soportes de disputa.
    final data = await HttpClient.uploadFile('/api/trips/$tripId/dispute/support', bytes: bytes, filename: filename, fieldName: 'file', auth: true, maxBytes: 10 * 1024 * 1024);
    return data['soporte'] as String? ?? data['url'] as String? ?? '';
  }
}
