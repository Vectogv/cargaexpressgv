import 'package:open_route_service/open_route_service.dart';
import 'package:latlong2/latlong.dart';

class RouteService {
  // ⚠️ Seguridad: la API key de OpenRouteService NO debe ir en el binario.
  // Se inyecta en runtime (debe servirse desde el backend, igual que el
  // token de Mapbox). Si no hay key configurada se usa la ruta en línea recta.
  static String? _apiKey;

  static String? get apiKey => _apiKey;

  static void configure({String? apiKey}) {
    _apiKey = apiKey;
  }

  static final Map<String, List<LatLng>> _cache = {};

  static Future<List<LatLng>> getRoute(LatLng origin, LatLng destination) async {
    final key = '${origin.latitude},${origin.longitude}|${destination.latitude},${destination.longitude}';
    if (_cache.containsKey(key)) return _cache[key]!;

    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      return [origin, destination];
    }

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