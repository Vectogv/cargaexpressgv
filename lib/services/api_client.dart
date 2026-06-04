import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_response.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  static const String baseUrl = 'http://localhost:3333';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  String? _token;
  String? _refreshToken;

  String? get token => _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
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

  Future<void> clearTokens() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
