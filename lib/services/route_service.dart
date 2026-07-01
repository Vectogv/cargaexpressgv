import 'package:open_route_service/open_route_service.dart';
import 'package:latlong2/latlong.dart';

class RouteService {
  static const String apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjRhZTE1NjgxMjMxMDRlZGM4MTNiODUxMDc1ZTIyZDFmIiwiaCI6Im11cm11cjY0In0=';
  static final Map<String, List<LatLng>> _cache = {};

  static Future<List<LatLng>> getRoute(LatLng origin, LatLng destination) async {
    final key = '${origin.latitude},${origin.longitude}|${destination.latitude},${destination.longitude}';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final ors = OpenRouteService(apiKey: apiKey, defaultProfile: ORSProfile.drivingCar);
      final response = await ors.directionsRouteCoordsGet(
        startCoordinate: ORSCoordinate(latitude: origin.latitude, longitude: origin.longitude),
        endCoordinate: ORSCoordinate(latitude: destination.latitude, longitude: destination.longitude),
      );
      final points = response.map((c) => LatLng(c.latitude, c.longitude)).toList();
      _cache[key] = points;
      return points;
    } catch (_) {
      return [origin, destination];
    }
  }
}
