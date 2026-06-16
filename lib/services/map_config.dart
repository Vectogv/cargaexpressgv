class MapConfig {
  MapConfig._();

  static const String mapboxAccessToken = 'token';

  static String get tileUrl {
    if (mapboxAccessToken.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$mapboxAccessToken';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }
}
