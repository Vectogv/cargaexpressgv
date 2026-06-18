import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_response.dart';
import 'api/auth_service.dart';
import 'api/trip_service.dart';
import 'api/offer_service.dart';
import 'api/chat_service.dart';
import 'api/driver_service.dart';
import 'api/profile_service.dart';
import 'api/payment_service.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  static const String baseUrl = 'https://zippy-trust-production.up.railway.app';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _nombreKey = 'auth_nombre';
  static const String _apellidoKey = 'auth_apellido';
  static const String _emailKey = 'auth_email';
  static const String _rolKey = 'auth_rol';

  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _nombre;
  String? _apellido;
  String? _email;
  String? _rol;

  String? get token => _token;
  String? get userId => _userId;
  String? get nombre => _nombre;
  String? get apellido => _apellido;
  String? get email => _email;
  String? get rol => _rol;

  String get nombreCompleto => '${_nombre ?? 'Admin'} ${_apellido ?? ''}'.trim();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _userId = prefs.getString(_userIdKey);
    _nombre = prefs.getString(_nombreKey);
    _apellido = prefs.getString(_apellidoKey);
    _email = prefs.getString(_emailKey);
    _rol = prefs.getString(_rolKey);
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) headers['Authorization'] = 'Bearer $_token';
    return headers;
  }

  // --- Auth ---

  Future<AuthResponse> login(String email, String password) async {
    final auth = await AuthService.login(email, password);
    await _saveTokens(auth.token, auth.refreshToken);
    await saveProfile(auth);
    return auth;
  }

  Future<AuthResponse> register(Map<String, dynamic> body) async {
    final auth = await AuthService.register(body);
    await _saveTokens(auth.token, auth.refreshToken);
    await saveProfile(auth);
    return auth;
  }

  Future<AuthResponse> refreshToken() async {
    if (_refreshToken == null) throw Exception('No hay refresh token');
    try {
      final auth = await AuthService.refreshToken(_refreshToken!);
      await _saveTokens(auth.token, auth.refreshToken);
      return auth;
    } catch (_) {
      await clearTokens();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await AuthService.logout();
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
    _userId = auth.id;
    _nombre = auth.nombre;
    _apellido = auth.apellido;
    _email = auth.email;
    _rol = auth.rol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, auth.id);
    await prefs.setString(_nombreKey, auth.nombre);
    await prefs.setString(_apellidoKey, auth.apellido);
    await prefs.setString(_emailKey, auth.email);
    await prefs.setString(_rolKey, auth.rol);
  }

  Future<void> clearTokens() async {
    _token = null;
    _refreshToken = null;
    _userId = null;
    _nombre = null;
    _apellido = null;
    _email = null;
    _rol = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nombreKey);
    await prefs.remove(_apellidoKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_rolKey);
  }

  // --- Profile ---

  Future<Map<String, dynamic>> getProfile() => ProfileService.getProfile();

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final body = await ProfileService.updateProfile(data);
    if (body['nombre'] != null) _nombre = body['nombre'] as String;
    if (body['apellido'] != null) _apellido = body['apellido'] as String;
    if (body['email'] != null) _email = body['email'] as String;
    final prefs = await SharedPreferences.getInstance();
    if (_nombre != null) await prefs.setString(_nombreKey, _nombre!);
    if (_apellido != null) await prefs.setString(_apellidoKey, _apellido!);
    if (_email != null) await prefs.setString(_emailKey, _email!);
  }

  Future<String> uploadAvatar(Uint8List bytes, String filename) => ProfileService.uploadAvatar(bytes, filename);

  // --- Documents ---

  Future<String> uploadDocumentCedula(Uint8List bytes, String filename) => DriverService.uploadDocumentCedula(bytes, filename);
  Future<String> uploadDocumentLicencia(Uint8List bytes, String filename) => DriverService.uploadDocumentLicencia(bytes, filename);
  Future<String> uploadDocumentVehiculo(Uint8List bytes, String filename) => DriverService.uploadDocumentVehiculo(bytes, filename);
  Future<String> uploadDocumentDriverPhoto(Uint8List bytes, String filename) => DriverService.uploadDocumentDriverPhoto(bytes, filename);

  // --- Trips ---

  Future<Map<String, dynamic>> requestTrip(Map<String, dynamic> data) => TripService.requestTrip(data);
  Future<Map<String, dynamic>?> getActiveTrip() => TripService.getActiveTrip();
  Future<List<Map<String, dynamic>>> getTripHistory({int page = 1, int limit = 20}) => TripService.getTripHistory(page: page, limit: limit);
  Future<Map<String, dynamic>> getTripDetail(dynamic id) => TripService.getTripDetail(id);
  Future<List<Map<String, dynamic>>> getNearbyTrips(double lat, double lng, {double radio = 5}) => TripService.getNearbyTrips(lat, lng, radio: radio);
  Future<void> startTrip(dynamic id) => TripService.startTrip(id);
  Future<void> completeTrip(dynamic id) => TripService.completeTrip(id);
  Future<void> finalizeTrip(dynamic id) => TripService.finalizeTrip(id);
  Future<void> cancelTrip(dynamic id, {String? motivo}) => TripService.cancelTrip(id, motivo: motivo);
  Future<void> requestCancellation(dynamic id, {String? motivo}) => TripService.requestCancellation(id, motivo: motivo);
  Future<void> disputeTrip(dynamic id, {required String motivo, String? descripcion}) => TripService.disputeTrip(id, motivo: motivo, descripcion: descripcion);
  Future<void> rateTrip(dynamic id, int puntaje, {String? comentario}) => TripService.rateTrip(id, puntaje, comentario: comentario);
  Future<String> deliveryPhoto(dynamic tripId, Uint8List bytes, String filename) => TripService.deliveryPhoto(tripId, bytes, filename);

  // --- Offers ---

  Future<Map<String, dynamic>> makeOffer(dynamic tripId, int monto, {String? placa}) => OfferService.makeOffer(tripId, monto, placa: placa);
  Future<List<Map<String, dynamic>>> getOffers(dynamic tripId) => OfferService.getOffers(tripId);
  Future<Map<String, dynamic>> acceptOffer(dynamic tripId, dynamic offerId) => OfferService.acceptOffer(tripId, offerId);
  Future<Map<String, dynamic>> rejectOffer(dynamic tripId, dynamic offerId) => OfferService.rejectOffer(tripId, offerId);

  // --- Chat ---

  Future<List<Map<String, dynamic>>> getTripMessages(dynamic tripId) => ChatService.getTripMessages(tripId);
  Future<void> sendTripMessage(dynamic tripId, String text) => ChatService.sendTripMessage(tripId, text);

  // --- Driver ---

  Future<void> setDriverStatus(bool online) => DriverService.setDriverStatus(online);
  Future<void> updateLocation(double lat, double lng) => DriverService.updateLocation(lat, lng);
  Future<Map<String, dynamic>> getEarnings() => DriverService.getEarnings();
  Future<Map<String, dynamic>> getDriverStats() => DriverService.getDriverStats();
  Future<Map<String, dynamic>> getTodayStats() => DriverService.getTodayStats();
  Future<Map<String, dynamic>> getDebt() => DriverService.getDebt();

  // --- Notifications & Misc ---

  Future<List<Map<String, dynamic>>> getNotifications() => ProfileService.getNotifications();
  Future<void> markNotificationRead(dynamic id) => ProfileService.markNotificationRead(id);
  Future<List<Map<String, dynamic>>> getForumPosts() => ProfileService.getForumPosts();
  Future<Map<String, dynamic>> createForumPost(Map<String, dynamic> data) => ProfileService.createForumPost(data);
  Future<Map<String, dynamic>> getSurveyResults(dynamic id) => ProfileService.getSurveyResults(id);
  Future<void> answerSurvey(dynamic id, dynamic opcionId) => ProfileService.answerSurvey(id, opcionId);
  Future<Map<String, dynamic>> getHelp() => ProfileService.getHelp();
  Future<Map<String, dynamic>> getEmergencyNumbers() => ProfileService.getEmergencyNumbers();
  Future<String> fetchMapboxToken() => ProfileService.fetchMapboxToken();
}
