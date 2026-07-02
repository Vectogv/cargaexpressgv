import 'dart:async';
import 'dart:convert';
import 'dart:io';

class _MockResponse {
  final int statusCode;
  final dynamic body;
  const _MockResponse(this.statusCode, this.body);
}

class MockServer {
  static const _clienteToken = 'mock_cliente_token_abc123';
  static const _conductorToken = 'mock_conductor_token_xyz789';

  late HttpServer _server;
  bool _started = false;

  Map<String, dynamic>? _activeTrip;
  final List<Map<String, dynamic>> _offers = [];
  int _nextId = 1;

  /// Public getter for test assertions
  Map<String, dynamic>? get activeTrip => _activeTrip;

  // --- Test control methods ---

  void setTripStatus(String status) {
    if (_activeTrip != null) {
      _activeTrip!['estado'] = status;
    }
  }

  void addOffer(Map<String, dynamic> offer) {
    _offers.add(offer);
  }

  void acceptOffer(String offerId) {
    _offers.removeWhere((o) => (o['_id'] ?? o['id']).toString() == offerId);
  }

  // --- Lifecycle ---

  Future<void> start() async {
    if (_started) return;
    _activeTrip = null;
    _offers.clear();
    _nextId = 1;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3333);
    _started = true;
    _server.listen(_handle);
  }

  Future<void> stop() async {
    if (!_started) return;
    await _server.close(force: true);
    _started = false;
  }

  // --- Request routing ---

  void _handle(HttpRequest request) async {
    try {
      final body = await utf8.decodeStream(request);
      final path = request.uri.path;
      final method = request.method;
      final data = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic>? : null;

      final response = _route(method, path, data, request.headers, request.uri);

      request.response.statusCode = response.statusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response.body));
      await request.response.close();
    } catch (e) {
      try {
        request.response.statusCode = 500;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'message': 'Mock error: $e'}));
        await request.response.close();
      } catch (_) {}
    }
  }

  _MockResponse _route(
    String method,
    String path,
    Map<String, dynamic>? data,
    HttpHeaders headers,
    Uri uri,
  ) {
    // --- Auth ---
    if (method == 'POST' && path == '/api/auth/login') {
      return _login(data);
    }
    if (method == 'POST' && path == '/api/auth/logout') {
      return _MockResponse(200, {'message': 'Sesión cerrada'});
    }
    if (method == 'POST' && path == '/api/auth/refresh-token') {
      return _MockResponse(200, {
        'token': _extractToken(headers) ?? _clienteToken,
        'refreshToken': 'mock_refresh_new',
        'id': 'user_001',
        'nombre': 'Test',
        'apellido': 'User',
        'email': 'test@test.com',
        'rol': 'cliente',
      });
    }

    // --- Profile ---
    if (method == 'GET' && path == '/api/users/profile') {
      return _profile(headers);
    }

    // --- Config ---
    if (path == '/api/config/mapbox-token') {
      return _MockResponse(200, {'token': ''});
    }

    // --- Trips ---
    if (method == 'POST' && path == '/api/trips/request') {
      return _requestTrip(data);
    }
    if (method == 'GET' && path == '/api/trips/active') {
      return _getActiveTrip(headers);
    }
    if (method == 'GET' && RegExp(r'^/api/trips/nearby').hasMatch(path)) {
      return _nearbyTrips(headers);
    }

    // --- Trip actions ---
      if (RegExp(r'^/api/trips/\w+/start-trip$').hasMatch(path) && method == 'POST') {
      return _startTrip();
    }
    if (RegExp(r'^/api/trips/\w+/finalize$').hasMatch(path) && method == 'POST') {
      return _finalizeTrip();
    }
    if (RegExp(r'^/api/trips/\w+/cancel$').hasMatch(path) && method == 'POST') {
      return _MockResponse(200, {'message': 'Viaje cancelado'});
    }

    // --- Offers ---
    if (method == 'POST' && RegExp(r'^/api/trips/\w+/offers$').hasMatch(path)) {
      return _makeOffer(data);
    }
    if (method == 'GET' && RegExp(r'^/api/trips/\w+/offers$').hasMatch(path)) {
      return _getOffers();
    }
    if (RegExp(r'^/api/trips/\w+/offers/\w+/accept$').hasMatch(path) && method == 'POST') {
      return _acceptOffer();
    }

    // --- Driver ---
    if (method == 'POST' && path == '/api/drivers/location') {
      return _MockResponse(200, {'message': 'ok'});
    }
    if (method == 'POST' && path == '/api/drivers/status') {
      return _MockResponse(200, {'message': 'ok'});
    }

    // --- Chats ---
    if (RegExp(r'^/api/trips/\w+/messages$').hasMatch(path)) {
      if (method == 'GET') return _MockResponse(200, []);
      return _MockResponse(200, {'message': 'ok'});
    }

    // --- Notifications ---
    if (path == '/api/notifications') {
      return _MockResponse(200, {'data': []});
    }

    // --- Misc catches (settings, help, etc.) ---
    return _MockResponse(200, {'message': 'ok'});
  }

  // --- Handler implementations ---

  String? _extractToken(HttpHeaders headers) {
    final auth = headers.value('authorization');
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    return auth.substring(7);
  }

  _MockResponse _login(Map<String, dynamic>? data) {
    final email = data?['email'] as String? ?? '';
    final password = data?['password'] as String? ?? '';
    if (password != '123456') {
      return _MockResponse(401, {'message': 'Credenciales inválidas'});
    }
    if (email == 'cliente@test.com') {
      return _MockResponse(200, {
        'token': _clienteToken,
        'refreshToken': 'mock_refresh_cliente',
        'id': 'cliente_id_001',
        'nombre': 'Cliente',
        'apellido': 'Test',
        'email': email,
        'rol': 'cliente',
      });
    }
    if (email == 'conductor@test.com') {
      return _MockResponse(200, {
        'token': _conductorToken,
        'refreshToken': 'mock_refresh_conductor',
        'id': 'conductor_id_001',
        'nombre': 'Conductor',
        'apellido': 'Test',
        'email': email,
        'rol': 'conductor',
      });
    }
    return _MockResponse(401, {'message': 'Usuario no encontrado'});
  }

  _MockResponse _profile(HttpHeaders headers) {
    final token = _extractToken(headers);
    if (token == _clienteToken) {
      return _MockResponse(200, {
        '_id': 'cliente_id_001',
        'nombre': 'Cliente',
        'apellido': 'Test',
        'email': 'cliente@test.com',
        'rol': 'cliente',
      });
    }
    if (token == _conductorToken) {
      return _MockResponse(200, {
        '_id': 'conductor_id_001',
        'nombre': 'Conductor',
        'apellido': 'Test',
        'email': 'conductor@test.com',
        'rol': 'conductor',
        'conductor': {'estadoVerificacion': 'aprobado', 'placa': 'ABC123'},
      });
    }
    return _MockResponse(401, {'message': 'No autorizado'});
  }

  _MockResponse _requestTrip(Map<String, dynamic>? data) {
    final tripId = 'trip_${_nextId++}';
    _activeTrip = {
      '_id': tripId,
      'id': tripId,
      'estado': 'buscando_conductor',
      'origen': data?['origen'] ?? {'lat': 10.0, 'lng': -74.5, 'direccion': 'Origen Test'},
      'destino': data?['destino'] ?? {'lat': 10.5, 'lng': -74.8, 'direccion': 'Destino Test'},
      'descripcion': data?['descripcion'] ?? 'Carga de prueba',
      'precioEstimado': data?['precioCliente'] ?? 200,
      'distancia': 5.0,
      'tiempoEstimado': 15,
      'cliente': {'_id': 'cliente_id_001', 'nombre': 'Cliente', 'apellido': 'Test'},
      'conductor': null,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    return _MockResponse(201, _activeTrip!);
  }

  _MockResponse _getActiveTrip(HttpHeaders headers) {
    final token = _extractToken(headers);
    if (_activeTrip == null) return _MockResponse(404, {'message': 'No active trip'});
    if (token == _clienteToken || token == _conductorToken) {
      return _MockResponse(200, _activeTrip!);
    }
    return _MockResponse(401, {'message': 'No autorizado'});
  }

  _MockResponse _nearbyTrips(HttpHeaders headers) {
    final token = _extractToken(headers);
    if (token != _conductorToken) return _MockResponse(200, []);
    if (_activeTrip != null && _activeTrip!['estado'] == 'buscando_conductor') {
      return _MockResponse(200, {'data': <Map<String, dynamic>>[_activeTrip!]});
    }
    return _MockResponse(200, {'data': <Map<String, dynamic>>[]});
  }

  _MockResponse _makeOffer(Map<String, dynamic>? data) {
    final offerId = 'offer_${_nextId++}';
    final offer = {
      '_id': offerId,
      'id': offerId,
      'conductor': {
        '_id': 'conductor_id_001',
        'nombre': 'Conductor',
        'apellido': 'Test',
        'calificacion': 4.5,
        'vehiculo': {'tipo': 'sedan', 'placa': 'ABC123'},
      },
      'monto': data?['monto'] ?? 200,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _offers.add(offer);
    return _MockResponse(201, offer);
  }

  _MockResponse _getOffers() {
    return _MockResponse(200, {'data': _offers});
  }

  _MockResponse _acceptOffer() {
    if (_activeTrip != null) {
      _activeTrip!['estado'] = 'aceptado';
      _activeTrip!['conductor'] = {
        '_id': 'conductor_id_001',
        'nombre': 'Conductor',
        'apellido': 'Test',
        'calificacion': 4.5,
      };
    }
    _offers.clear();
    return _MockResponse(200, {'message': 'Oferta aceptada'});
  }

  _MockResponse _startTrip() {
    if (_activeTrip != null) {
      _activeTrip!['estado'] = 'en_curso';
      _activeTrip!['inicio'] = DateTime.now().toIso8601String();
    }
    return _MockResponse(200, {'message': 'Viaje iniciado'});
  }

  _MockResponse _finalizeTrip() {
    if (_activeTrip != null) {
      _activeTrip!['estado'] = 'finalizado';
    }
    return _MockResponse(200, {'message': 'Viaje finalizado'});
  }
}
