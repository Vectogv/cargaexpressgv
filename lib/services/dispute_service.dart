import 'dart:io';
import 'api_client.dart';

class DisputeService {
  final ApiClient _api = ApiClient();

  Future<void> reportDispute(String tripId, String version) async {
    await _api.post('/trips/$tripId/dispute', body: {
      'version': version,
    });
  }

  Future<void> appealDispute(String tripId, {required String version, File? soporte}) async {
    if (soporte != null) {
      await _api.upload('/trips/$tripId/dispute/appeal', soporte.path, 'soporte', fields: {
        'version': version,
      });
    } else {
      await _api.post('/trips/$tripId/dispute/appeal', body: {
        'version': version,
      });
    }
  }
}
