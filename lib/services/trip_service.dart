import '../models/trip.dart';
import 'api_client.dart';

class TripService {
  final ApiClient _api = ApiClient();

  Future<Trip> requestTrip({
    required String origenDireccion,
    required double origenLat,
    required double origenLng,
    required String destinoDireccion,
    required double destinoLat,
    required double destinoLng,
    required double precioCliente,
    String? descripcion,
  }) async {
    final body = {
      'origen': {'direccion': origenDireccion, 'lat': origenLat, 'lng': origenLng},
      'destino': {'direccion': destinoDireccion, 'lat': destinoLat, 'lng': destinoLng},
      'precioCliente': precioCliente,
      if (descripcion != null) 'descripcion': descripcion,
    };
    final res = await _api.post('/trips/request', body: body);
    return Trip.fromJson(res);
  }

  Future<List<Trip>> getNearby({required double lat, required double lng, int radio = 5}) async {
    final res = await _api.getList('/trips/nearby', query: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radio': radio.toString(),
    });
    return res.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Trip?> getActiveTrip() async {
    try {
      final res = await _api.get('/trips/active');
      return Trip.fromJson(res);
    } catch (e) {
      return null;
    }
  }

  Future<void> acceptTrip(String id) async {
    await _api.post('/trips/$id/accept');
  }

  Future<void> declineTrip(String id) async {
    await _api.post('/trips/$id/decline');
  }

  Future<void> startTrip(String id) async {
    await _api.post('/trips/$id/start-trip');
  }

  Future<void> completeTrip(String id, {required double montoFinal}) async {
    await _api.post('/trips/$id/complete', body: {'montoFinal': montoFinal});
  }

  Future<void> finalizeTrip(String id, {required double montoFinal}) async {
    await _api.post('/trips/$id/finalize', body: {'montoFinal': montoFinal});
  }

  Future<void> cancelTrip(String id, {String? motivo}) async {
    await _api.post('/trips/$id/cancel', body: {if (motivo != null) 'motivo': motivo});
  }

  Future<List<Trip>> getHistory({int page = 1, int limit = 20}) async {
    final res = await _api.get('/trips/history', query: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return (res['data'] as List).map((e) => Trip.fromJson(e)).toList();
  }

  Future<Trip> getTrip(String id) async {
    final res = await _api.get('/trips/$id');
    return Trip.fromJson(res);
  }

  Future<List<Map<String, dynamic>>> getOffers(String tripId) async {
    final res = await _api.getList('/trips/$tripId/offers');
    return res.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> acceptOffer(String tripId, String offerId) async {
    return await _api.post('/trips/$tripId/offers/$offerId/accept');
  }

  Future<Map<String, dynamic>> sendOffer(String tripId, {required double monto}) async {
    return await _api.post('/trips/$tripId/offers', body: {'monto': monto});
  }

  Future<void> reportClient(String tripId, String motivo) async {
    await _api.post('/trips/$tripId/report-client', body: {'motivo': motivo});
  }
}
