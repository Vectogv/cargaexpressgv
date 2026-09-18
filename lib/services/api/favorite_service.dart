import 'http_client.dart';

class FavoriteService {
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final list = await HttpClient.getList('/api/favorites', auth: true);
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createFavorite({
    required String nombre,
    required String origenDireccion,
    required double origenLat,
    required double origenLng,
    required String destinoDireccion,
    required double destinoLat,
    required double destinoLng,
  }) async {
    return HttpClient.post('/api/favorites', body: {
      'nombre': nombre,
      'origenDireccion': origenDireccion,
      'origenLat': origenLat,
      'origenLng': origenLng,
      'destinoDireccion': destinoDireccion,
      'destinoLat': destinoLat,
      'destinoLng': destinoLng,
    }, auth: true);
  }

  static Future<void> deleteFavorite(dynamic id) async {
    await HttpClient.delete('/api/favorites/$id', auth: true);
  }
}
