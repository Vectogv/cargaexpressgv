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

  static Future<void> logout() async {
    try {
      await HttpClient.post('/api/auth/logout', auth: true);
    } catch (_) {}
  }
}
