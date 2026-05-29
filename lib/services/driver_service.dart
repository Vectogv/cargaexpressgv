import '../models/driver.dart';
import 'api_client.dart';

class DriverService {
  final ApiClient _api = ApiClient();

  Future<void> setStatus(bool online) async {
    await _api.put('/drivers/status', body: {'online': online});
  }

  Future<DriverEarnings> getEarnings() async {
    final res = await _api.get('/drivers/earnings');
    return DriverEarnings.fromJson(res);
  }

  Future<DriverStats> getStats() async {
    final res = await _api.get('/drivers/stats');
    return DriverStats.fromJson(res);
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    return await _api.get('/drivers/today-stats');
  }

  Future<String> uploadVehiclePhoto(String filePath, {List<int>? bytes, String? filename}) async {
    final res = bytes != null
        ? await _api.uploadBytes('/drivers/vehicle-photo', bytes, filename ?? 'vehicle.jpg', 'file')
        : await _api.upload('/drivers/vehicle-photo', filePath, 'file');
    return res['fotoVehiculo'];
  }

  Future<String> uploadDriverPhoto(String filePath, {List<int>? bytes, String? filename}) async {
    final res = bytes != null
        ? await _api.uploadBytes('/drivers/driver-photo', bytes, filename ?? 'driver.jpg', 'file')
        : await _api.upload('/drivers/driver-photo', filePath, 'file');
    return res['fotoConductor'];
  }

  Future<void> updateLocation(double lat, double lng) async {
    await _api.put('/drivers/location', body: {'lat': lat, 'lng': lng});
  }
}
