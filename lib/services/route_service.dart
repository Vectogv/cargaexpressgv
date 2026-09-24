import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:open_route_service/open_route_service.dart';
import 'package:latlong2/latlong.dart';

import 'map_config.dart';

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
      // Sin key de ORS: ruta por calles con Mapbox Directions (el token ya lo
      // sirve el backend en /api/config/mapbox); si tampoco hay, línea recta.
      final mapbox = await _rutaMapbox(origin, destination);
      if (mapbox != null) _cache[key] = mapbox;
      return mapbox ?? [origin, destination];
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

  /// Cliente HTTP inyectable en tests.
  static http.Client Function() clientFactory = http.Client.new;

  static Future<List<LatLng>?> _rutaMapbox(LatLng origin, LatLng destination) async {
    await MapConfig.ensureLoaded();
    final token = MapConfig.mapboxAccessToken;
    if (token.isEmpty) return null;
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving/'
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
      {'geometries': 'geojson', 'overview': 'full', 'access_token': token},
    );
    final client = clientFactory();
    try {
      final res = await client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return parseRutaMapbox(jsonDecode(res.body));
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Puntos de la primera ruta de una respuesta de Mapbox Directions
  /// (GeoJSON: `[lng, lat]`); null si no hay ruta utilizable.
  static List<LatLng>? parseRutaMapbox(Object? json) {
    if (json is! Map) return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final geometry = (routes.first as Map?)?['geometry'];
    final coords = geometry is Map ? geometry['coordinates'] : null;
    if (coords is! List || coords.length < 2) return null;
    final puntos = <LatLng>[];
    for (final c in coords) {
      if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
        puntos.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
    }
    return puntos.length >= 2 ? puntos : null;
  }
}
