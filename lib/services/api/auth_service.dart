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

  /// Entrar con Google: el servidor valida el idToken y crea un cliente si el
  /// correo es nuevo.
  static Future<AuthResponse> google(String idToken) async {
    final data = await HttpClient.post('/api/auth/google', body: {'idToken': idToken});
    return AuthResponse.fromJson(data);
  }

  static Future<AuthResponse> refreshToken(String refreshToken) async {
    final data = await HttpClient.post('/api/auth/refresh-token', body: {'refreshToken': refreshToken});
    return AuthResponse.fromJson(data);
  }

  /// Envía un código de 6 dígitos al correo (Brevo). El backend responde lo
  /// mismo exista o no la cuenta.
  static Future<void> forgotPassword(String email) async {
    await HttpClient.post('/api/auth/forgot-password', body: {'email': email});
  }

  static Future<void> resetPassword(String email, String codigo, String password) async {
    await HttpClient.post('/api/auth/reset-password', body: {'email': email, 'codigo': codigo, 'password': password});
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
