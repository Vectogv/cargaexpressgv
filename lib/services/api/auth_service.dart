import '../auth_response.dart';
import 'http_client.dart';

class AuthService {
  static Future<AuthResponse> login(String email, String password) async {
    final data = await HttpClient.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(data);
  }

  static Future<AuthResponse> register(Map<String, dynamic> body) async {
    final data = await HttpClient.post('/api/auth/register', body: body);
    return AuthResponse.fromJson(data);
  }

  static Future<AuthResponse> refreshToken(String refreshToken) async {
    final data = await HttpClient.post('/api/auth/refresh-token', body: {'refreshToken': refreshToken});
    return AuthResponse.fromJson(data);
  }

  /// Revoca el refresh token (el backend lo acepta aunque el access token
  /// haya expirado). Nunca lanza: el logout local no depende de la red.
  static Future<void> logout({String? refreshToken}) async {
    try {
      await HttpClient.post(
        '/api/auth/logout',
        body: {if (refreshToken != null) 'refreshToken': refreshToken},
        auth: true,
      );
    } catch (_) {}
  }
}
