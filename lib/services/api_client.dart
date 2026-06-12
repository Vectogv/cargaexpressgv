import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_response.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  static const String baseUrl = 'https://zippy-trust-production.up.railway.app';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _nombreKey = 'auth_nombre';
  static const String _apellidoKey = 'auth_apellido';
  static const String _emailKey = 'auth_email';
  static const String _rolKey = 'auth_rol';

  String? _token;
  String? _refreshToken;
  String? _nombre;
  String? _apellido;
  String? _email;
  String? _rol;

  String? get token => _token;
  String? get nombre => _nombre;
  String? get apellido => _apellido;
  String? get email => _email;
  String? get rol => _rol;

  String get nombreCompleto => '${_nombre ?? 'Admin'} ${_apellido ?? ''}'.trim();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _nombre = prefs.getString(_nombreKey);
    _apellido = prefs.getString(_apellidoKey);
    _email = prefs.getString(_emailKey);
    _rol = prefs.getString(_rolKey);
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<AuthResponse> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(_extractError(data));
    }
    final auth = AuthResponse.fromJson(data);
    await _saveTokens(auth.token, auth.refreshToken);
    await saveProfile(auth);
    return auth;
  }

  String _extractError(Map<String, dynamic> data) {
    if (data['message'] != null) return data['message'] as String;
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      return (errors[0] as Map<String, dynamic>)['message'] as String? ?? 'Error desconocido';
    }
    if (data['error'] != null) return data['error'] as String;
    return 'Error desconocido';
  }

  Future<AuthResponse> register(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_extractError(data));
    }
    final auth = AuthResponse.fromJson(data);
    await _saveTokens(auth.token, auth.refreshToken);
    await saveProfile(auth);
    return auth;
  }

  Future<AuthResponse> refreshToken() async {
    if (_refreshToken == null) throw Exception('No hay refresh token');
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/refresh-token'),
      headers: _headers(),
      body: jsonEncode({'refreshToken': _refreshToken}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      await clearTokens();
      throw Exception('Sesión expirada');
    }
    final auth = AuthResponse.fromJson(data);
    await _saveTokens(auth.token, auth.refreshToken);
    return auth;
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/auth/logout'),
        headers: _headers(auth: true),
      );
    } catch (_) {}
    await clearTokens();
  }

  Future<void> _saveTokens(String token, String refreshToken) async {
    _token = token;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<void> saveProfile(AuthResponse auth) async {
    _nombre = auth.nombre;
    _apellido = auth.apellido;
    _email = auth.email;
    _rol = auth.rol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nombreKey, auth.nombre);
    await prefs.setString(_apellidoKey, auth.apellido);
    await prefs.setString(_emailKey, auth.email);
    await prefs.setString(_rolKey, auth.rol);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/users/profile'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception('Error al obtener perfil');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/users/profile'),
      headers: _headers(auth: true),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Error al actualizar perfil');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['nombre'] != null) _nombre = body['nombre'] as String;
    if (body['apellido'] != null) _apellido = body['apellido'] as String;
    if (body['email'] != null) _email = body['email'] as String;
    final prefs = await SharedPreferences.getInstance();
    if (_nombre != null) await prefs.setString(_nombreKey, _nombre!);
    if (_apellido != null) await prefs.setString(_apellidoKey, _apellido!);
    if (_email != null) await prefs.setString(_emailKey, _email!);
  }

  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/users/avatar'),
    );
    request.headers.addAll(_headers(auth: true));
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) throw Exception('Error al subir avatar');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['avatar'] as String? ?? '';
  }

  Future<String> uploadDocumentCedula(Uint8List bytes, String filename) async {
    return _uploadDocument('$baseUrl/api/drivers/verification/cedula', bytes, filename, 'fotoCedula');
  }

  Future<String> uploadDocumentLicencia(Uint8List bytes, String filename) async {
    return _uploadDocument('$baseUrl/api/drivers/verification/licencia', bytes, filename, 'fotoLicencia');
  }

  Future<String> uploadDocumentVehiculo(Uint8List bytes, String filename) async {
    return _uploadDocument('$baseUrl/api/drivers/verification/vehiculo', bytes, filename, 'fotoVehiculo');
  }

  Future<String> uploadDocumentDriverPhoto(Uint8List bytes, String filename) async {
    return _uploadDocument('$baseUrl/api/drivers/driver-photo', bytes, filename, 'fotoConductor');
  }

  Future<String> _uploadDocument(String url, Uint8List bytes, String filename, String field) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(_headers(auth: true));
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) throw Exception('Error al subir documento');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body[field] as String? ?? '';
  }

  Future<Map<String, dynamic>> requestTrip(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/request'),
      headers: _headers(auth: true),
      body: jsonEncode(data),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(_extractError(jsonDecode(res.body)));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getActiveTrip() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/trips/active'),
      headers: _headers(auth: true),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getTripHistory({int page = 1, int limit = 20}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/trips/history?page=$page&limit=$limit'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<Map<String, dynamic>> getTripDetail(dynamic id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/trips/$id'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getOffers(dynamic tripId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/trips/$tripId/offers'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
    final body = jsonDecode(res.body) as List;
    return body.cast<Map<String, dynamic>>();
  }

  Future<void> acceptOffer(dynamic tripId, dynamic offerId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$tripId/offers/$offerId/accept'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
  }

  Future<void> cancelTrip(dynamic id, {String? motivo}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$id/cancel'),
      headers: _headers(auth: true),
      body: jsonEncode({'motivo': motivo}),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
  }

  Future<void> requestCancellation(dynamic id, {String? motivo}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$id/request-cancellation'),
      headers: _headers(auth: true),
      body: jsonEncode({'motivo': motivo}),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
  }

  Future<void> rateTrip(dynamic id, int puntaje, {String? comentario}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$id/rate'),
      headers: _headers(auth: true),
      body: jsonEncode({'puntaje': puntaje, 'comentario': comentario}),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
  }

  Future<List<Map<String, dynamic>>> getNearbyTrips(double lat, double lng, {double radio = 5}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/trips/nearby?lat=$lat&lng=$lng&radio=$radio'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
    final body = jsonDecode(res.body) as List;
    return body.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> makeOffer(dynamic tripId, int monto) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$tripId/offers'),
      headers: _headers(auth: true),
      body: jsonEncode({'monto': monto}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(_extractError(jsonDecode(res.body)));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> startTrip(dynamic id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$id/start-trip'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
  }

  Future<void> completeTrip(dynamic id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$id/complete'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
  }

  Future<void> finalizeTrip(dynamic id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/trips/$id/finalize'),
      headers: _headers(auth: true),
    );
    if (res.statusCode != 200) throw Exception(_extractError(jsonDecode(res.body)));
  }

  Future<void> deliveryPhoto(dynamic tripId, Uint8List bytes, String filename) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/trips/$tripId/delivery-photo'),
    );
    req.headers.addAll(_headers(auth: true));
    req.files.add(http.MultipartFile.fromBytes('foto', bytes, filename: filename));
    final res = await req.send();
    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      throw Exception(_extractError(jsonDecode(body)));
    }
  }

  Future<void> clearTokens() async {
    _token = null;
    _refreshToken = null;
    _nombre = null;
    _apellido = null;
    _email = null;
    _rol = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_nombreKey);
    await prefs.remove(_apellidoKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_rolKey);
  }
}
