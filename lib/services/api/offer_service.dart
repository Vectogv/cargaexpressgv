import 'http_client.dart';

class OfferService {
  static Future<Map<String, dynamic>> makeOffer(dynamic tripId, int monto) async {
    return HttpClient.post('/api/trips/$tripId/offers', body: {'monto': monto}, auth: true);
  }

  static Future<List<Map<String, dynamic>>> getOffers(dynamic tripId) async {
    final list = await HttpClient.getList('/api/trips/$tripId/offers', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> acceptOffer(dynamic tripId, dynamic offerId) async {
    await HttpClient.post('/api/trips/$tripId/offers/$offerId/accept', auth: true);
  }
}
