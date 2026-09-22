import 'api/profile_service.dart';
import 'api_client.dart';
import 'logger_service.dart';

class MapConfig {
  MapConfig._();

  static String mapboxAccessToken = '';
  static Future<void>? _loading;

  static String get tileUrl {
    if (mapboxAccessToken.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$mapboxAccessToken';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// Obtiene el token de Mapbox si aún no se tiene. El endpoint exige sesión,
  /// así que sin token de usuario no se llama (evita el 401 al arrancar) y se
  /// reintenta tras login/registro.
  static Future<void> ensureLoaded() {
    if (mapboxAccessToken.isNotEmpty || ApiClient.instance.token == null) {
      return Future.value();
    }
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  static Future<void> _fetch() async {
    try {
      mapboxAccessToken = await ProfileService.fetchMapboxToken();
    } catch (_) {
      LoggerService.instance.debug('Mapbox token not available, using OSM fallback');
    }
  }
}
