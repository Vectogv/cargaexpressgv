import 'dart:async';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/environment.dart';
import 'auth_response.dart';
import 'api/auth_service.dart';
import 'api/http_client.dart' show ApiException;
import 'api/trip_service.dart';
import 'api/offer_service.dart';
import 'api/chat_service.dart';
import 'api/driver_service.dart';
import 'api/profile_service.dart';
import 'api/dispute_service.dart';
import 'api/favorite_service.dart';
import 'map_config.dart';
import 'socket_service_client.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  static String get baseUrl => Environment.baseUrl;
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _nombreKey = 'auth_nombre';
  static const String _apellidoKey = 'auth_apellido';
  static const String _emailKey = 'auth_email';
  static const String _rolKey = 'auth_rol';
  static const String _esModeradorKey = 'auth_es_moderador';
  static const String _zonaModeradorKey = 'auth_zona_moderador';

  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _nombre;
  String? _apellido;
  String? _email;
  String? _rol;
  bool _esModerador = false;
  String? _zonaModerador;

  String? get token => _token;
  String? get userId => _userId;
  String? get nombre => _nombre;
  String? get apellido => _apellido;
  String? get email => _email;
  String? get rol => _rol;
  bool get esModerador => _esModerador;
  String? get zonaModerador => _zonaModerador;

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
    _esModerador = prefs.getBool(_esModeradorKey) ?? false;
    _zonaModerador = prefs.getString(_zonaModeradorKey);
  }

  // --- Auth ---

  Future<AuthResponse> login(String email, String password) async {
    final auth = await AuthService.login(email, password);
    await _saveTokens(auth.token, auth.refreshToken);
    await saveProfile(auth);
    unawaited(MapConfig.ensureLoaded());
    return auth;
  }

  Future<AuthResponse> register(Map<String, dynamic> body) async {
    final auth = await AuthService.register(body);
    await _saveTokens(auth.token, auth.refreshToken);
    await saveProfile(auth);
    unawaited(MapConfig.ensureLoaded());
    return auth;
  }

  /// `true` si el backend rechazó explícitamente el refresh token (sesión
  /// terminada). Errores de red, timeouts, 429 y 5xx NO cuentan: la sesión se
  /// conserva y se reintenta más tarde.
  static bool isRefreshRejection(ApiException e) {
    final status = e.statusCode;
    return status == 400 || status == 401 || status == 422;
  }

  /// Renueva el access token. Los refresh tokens son de un solo uso: usar
  /// `HttpClient.refreshSessionShared()` para compartir la renovación en vuelo
  /// entre peticiones concurrentes en vez de llamar a este método en paralelo.
  ///
  /// Sólo limpia la sesión si el backend rechaza el refresh token
  /// (400/401/422); ante fallos transitorios conserva los tokens y relanza.
  Future<AuthResponse> refreshToken() async {
    final current = _refreshToken;
    if (current == null) {
      throw ApiException('No hay refresh token', statusCode: 401, code: 'SIN_REFRESH_TOKEN');
    }
    try {
      final auth = await AuthService.refreshToken(current);
      // El endpoint de refresh (según el contrato) sólo devuelve token/refreshToken.
      // Actualizamos únicamente los tokens y conservamos el perfil en memoria.
      if (auth.token.isNotEmpty) _token = auth.token;
      if (auth.refreshToken != null && auth.refreshToken!.isNotEmpty) {
        _refreshToken = auth.refreshToken;
      }
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) await prefs.setString(_tokenKey, _token!);
      if (_refreshToken != null) {
        await prefs.setString(_refreshTokenKey, _refreshToken!);
      }
      return auth;
    } on ApiException catch (e) {
      if (isRefreshRejection(e)) await clearTokens();
      rethrow;
    }
  }

  /// Relee los tokens desde SharedPreferences (otro isolate pudo rotarlos).
  /// Lo usa el isolate del servicio de ubicación en segundo plano, que nunca
  /// renueva tokens por su cuenta.
  Future<void> reloadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
  }

  /// Cierra sesión: revoca el refresh token en el backend (sin bloquear si no
  /// hay red) y limpia la sesión local.
  Future<void> logout() async {
    final refresh = _refreshToken;
    try {
      await AuthService.logout(refreshToken: refresh)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await clearTokens();
  }

  Future<void> _saveTokens(String token, String? refreshToken) async {
    _token = token;
    if (refreshToken != null) _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
    // Conectar el socket apenas exista sesión (cubre login/registro en frío,
    // donde init() se ejecutó sin token y nunca conectó).
    SocketServiceClient.instance.forceReconnect();
  }

  Future<void> saveProfile(AuthResponse auth) async {
    _userId = auth.id;
    _nombre = auth.nombre;
    _apellido = auth.apellido;
    _email = auth.email;
    _rol = auth.rol;
    _esModerador = auth.esModerador;
    _zonaModerador = auth.zonaModerador;
    final prefs = await SharedPreferences.getInstance();
    if (auth.id != null) await prefs.setString(_userIdKey, auth.id!);
    if (auth.nombre != null) await prefs.setString(_nombreKey, auth.nombre!);
    if (auth.apellido != null) await prefs.setString(_apellidoKey, auth.apellido!);
    if (auth.email != null) await prefs.setString(_emailKey, auth.email!);
    if (auth.rol != null) await prefs.setString(_rolKey, auth.rol!);
    await prefs.setBool(_esModeradorKey, auth.esModerador);
    if (auth.zonaModerador != null) {
      await prefs.setString(_zonaModeradorKey, auth.zonaModerador!);
    } else {
      await prefs.remove(_zonaModeradorKey);
    }
  }

  Future<void> clearTokens() async {
    _token = null;
    _refreshToken = null;
    _userId = null;
    _nombre = null;
    _apellido = null;
    _email = null;
    _rol = null;
    _esModerador = false;
    _zonaModerador = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nombreKey);
    await prefs.remove(_apellidoKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_rolKey);
    await prefs.remove(_esModeradorKey);
    await prefs.remove(_zonaModeradorKey);
    // Cerrar el socket de la sesión anterior para no recibir eventos con
    // un token inválido ni mezclar usuarios.
    SocketServiceClient.instance.disconnect();
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
  Future<String> uploadVehiclePhoto(Uint8List bytes, String filename) => DriverService.uploadVehiclePhoto(bytes, filename);

  // --- Trips ---

  Future<Map<String, dynamic>> requestTrip(Map<String, dynamic> data, {String? idempotencyKey}) => TripService.requestTrip(data, idempotencyKey: idempotencyKey);
  Future<Map<String, dynamic>?> getActiveTrip() => TripService.getActiveTrip();
  Future<List<Map<String, dynamic>>> getTripHistory({int page = 1, int limit = 20, String? estado}) => TripService.getTripHistory(page: page, limit: limit, estado: estado);
  Future<Map<String, dynamic>> getTripDetail(dynamic id) => TripService.getTripDetail(id);
  Future<List<Map<String, dynamic>>> getNearbyTrips(double lat, double lng, {double radio = 5}) => TripService.getNearbyTrips(lat, lng, radio: radio);
  Future<void> startTrip(dynamic id) => TripService.startTrip(id);
  Future<void> confirmArrival(dynamic id) => TripService.confirmArrival(id);
  Future<void> confirmPickup(dynamic id) => TripService.confirmPickup(id);
  Future<Map<String, dynamic>> reserveTrip(Map<String, dynamic> data, {String? idempotencyKey}) => TripService.reserveTrip(data, idempotencyKey: idempotencyKey);
  Future<List<Map<String, dynamic>>> getReservations({int page = 1, int limit = 20, String? estado}) => TripService.getReservations(page: page, limit: limit, estado: estado);
  Future<void> declineTrip(dynamic id) => TripService.declineTrip(id);
  Future<Map<String, dynamic>> disputeAppeal(dynamic id, {required String motivo, String? descripcion}) => TripService.disputeAppeal(id, motivo: motivo, descripcion: descripcion);
  Future<void> completeTrip(dynamic id, {num? montoFinal, String? justificacion, String? idempotencyKey}) => TripService.completeTrip(id, montoFinal: montoFinal, justificacion: justificacion, idempotencyKey: idempotencyKey);
  Future<void> finalizeTrip(dynamic id, {num? montoFinal, String? justificacion, String? idempotencyKey}) => TripService.finalizeTrip(id, montoFinal: montoFinal, justificacion: justificacion, idempotencyKey: idempotencyKey);
  Future<void> cancelTrip(dynamic id, {String? motivo, String? justificacion}) => TripService.cancelTrip(id, motivo: motivo, justificacion: justificacion);
  Future<void> requestCancellation(dynamic id, {String? motivo, String? justificacion}) => TripService.requestCancellation(id, motivo: motivo, justificacion: justificacion);
  Future<Map<String, dynamic>> confirmClose(dynamic id, {required bool confirmar, String? motivo, String? idempotencyKey}) => TripService.confirmClose(id, confirmar: confirmar, motivo: motivo, idempotencyKey: idempotencyKey);
  Future<Map<String, dynamic>> disputeTrip(dynamic id, {required String motivo, String? descripcion}) => TripService.disputeTrip(id, motivo: motivo, descripcion: descripcion);
  Future<void> rateTrip(dynamic id, int puntaje, {String? comentario}) => TripService.rateTrip(id, puntaje, comentario: comentario);
  Future<String> deliveryPhoto(dynamic tripId, Uint8List bytes, String filename) => TripService.deliveryPhoto(tripId, bytes, filename);

  // --- Disputes ---

  Future<Map<String, dynamic>> createDispute({required dynamic tripId, required String problema, String? descripcion, List<String>? fotos}) =>
      DisputeService.createDispute(tripId: tripId, problema: problema, descripcion: descripcion, fotos: fotos);
  Future<Map<String, dynamic>> getDispute(dynamic id) => DisputeService.getDispute(id);
  Future<Map<String, dynamic>> submitVersion(dynamic id, String version) => DisputeService.submitVersion(id, version);

  // --- Favorites ---

  Future<List<Map<String, dynamic>>> getFavorites() => FavoriteService.getFavorites();
  Future<Map<String, dynamic>> createFavorite({
    required String nombre,
    required String origenDireccion,
    required double origenLat,
    required double origenLng,
    required String destinoDireccion,
    required double destinoLat,
    required double destinoLng,
  }) => FavoriteService.createFavorite(
        nombre: nombre,
        origenDireccion: origenDireccion,
        origenLat: origenLat,
        origenLng: origenLng,
        destinoDireccion: destinoDireccion,
        destinoLat: destinoLat,
        destinoLng: destinoLng,
      );
  Future<void> deleteFavorite(dynamic id) => FavoriteService.deleteFavorite(id);

  // --- Offers ---

  Future<Map<String, dynamic>> makeOffer(dynamic tripId, int monto, {String? placa, String? mensaje}) => OfferService.makeOffer(tripId, monto, placa: placa, mensaje: mensaje);
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
  Future<Map<String, dynamic>> getEarningsHistory({String periodo = 'todo', int page = 1, int limit = 20}) => DriverService.getEarningsHistory(periodo: periodo, page: page, limit: limit);
  Future<List<int>> getEarningsPdf({String periodo = 'todo'}) => DriverService.getEarningsPdf(periodo: periodo);

  // --- Settings ---

  Future<Map<String, dynamic>> getSettings() => ProfileService.getSettings();
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data) => ProfileService.updateSettings(data);

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