import 'package:geolocator/geolocator.dart';
import 'api/http_client.dart';
import '../models/sos_alert_model.dart';
import 'logger_service.dart';

class SosService {
  static Future<SosAlertModel> sendAlert({String? tripId}) async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (e) {
      LoggerService.instance.error('SosService: GPS error, using fallback position', e);
      pos = Position(longitude: 0, latitude: 0, timestamp: DateTime.now(), accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);
    }

    final payload = {
      'viajeId': tripId,
      'lat': pos.latitude,
      'lng': pos.longitude,
    };

    try {
      final data = await HttpClient.post('/api/emergency', body: payload, auth: true);
      return SosAlertModel.fromJson(data);
    } catch (e) {
      LoggerService.instance.error('SosService.sendAlert: API error', e);
      rethrow;
    }
  }
}
