import 'http_client.dart';

class OfferService {
  static Future<Map<String, dynamic>> makeOffer(dynamic tripId, int monto, {String? placa, String? mensaje}) async {
    final body = <String, dynamic>{'monto': monto};
    if (placa != null && placa.isNotEmpty) {
      body['placa'] = placa;
    }
    if (mensaje != null && mensaje.trim().isNotEmpty) {
      body['mensaje'] = mensaje.trim();
    }
    return HttpClient.post('/api/trips/$tripId/offers', body: body, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getOffers(dynamic tripId) async {
    final list = await HttpClient.getList('/api/trips/$tripId/offers', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> acceptOffer(dynamic tripId, dynamic offerId) async {
    return HttpClient.post('/api/trips/$tripId/offers/$offerId/accept', auth: true);
  }

  static Future<Map<String, dynamic>> rejectOffer(dynamic tripId, dynamic offerId) async {
    return HttpClient.post('/api/trips/$tripId/offers/$offerId/reject', auth: true);
  }
}
