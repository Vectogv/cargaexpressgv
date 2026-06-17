class MapConfig {
  MapConfig._();

  static String _mapboxAccessToken = '';

  static String get mapboxAccessToken => _mapboxAccessToken;

  static set mapboxAccessToken(String value) => _mapboxAccessToken = value;

  static String get tileUrl {
    if (_mapboxAccessToken.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$_mapboxAccessToken';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }
}