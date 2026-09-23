import 'package:geolocator/geolocator.dart';
import 'api/http_client.dart';
import '../models/sos_alert_model.dart';
import 'location_permission.dart';
import 'logger_service.dart';

class SosService {
  /// Posición para el SOS sin bloquearlo: actual (con límites cortos), si no
  /// la última conocida; null si no hay ninguna. No abre los ajustes del
  /// sistema: el SOS no debe sacar al usuario de la app.
  static Future<Position?> _posicionParaSos() async {
    try {
      await LocationPermissionHelper.ensure(openSettings: false);
      return await LocationPermissionHelper.currentPosition(
        timeLimit: const Duration(seconds: 5),
        fallbackLimit: const Duration(seconds: 3),
      );
    } catch (e) {
      LoggerService.instance.error('SosService: sin GPS, se intenta la última posición conocida', e);
    }
    try {
      return await LocationPermissionHelper.lastKnown().timeout(const Duration(seconds: 3));
    } catch (e) {
      LoggerService.instance.error('SosService: sin última posición conocida', e);
      return null;
    }
  }

  static Future<SosAlertModel> sendAlert({String? tripId, String? motivo}) async {
    final pos = await _posicionParaSos();

    // Sin posición se envía igual: el backend acepta lat/lng nulos (antes se
    // mandaba 0,0, una ubicación falsa en el golfo de Guinea).
    final payload = {
      'viajeId': tripId,
      if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      if (pos != null) 'lat': pos.latitude,
      if (pos != null) 'lng': pos.longitude,
    };

    try {
      final data = await HttpClient.post('/api/emergency', body: payload, auth: true);
      return SosAlertModel.fromJson(data);
    } catch (e) {
      LoggerService.instance.error('SosService.sendAlert: API error', e);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getChatMessages(dynamic alertaId) async {
    final list = await HttpClient.getList('/api/emergency/$alertaId/messages', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> sendChatMessage(dynamic alertaId, String mensaje) async {
    return HttpClient.post('/api/emergency/$alertaId/messages', body: {'mensaje': mensaje}, auth: true);
  }
}
