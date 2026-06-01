import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<User> register({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required String telefono,
    required String rol,
    int? edad,
    String? cedula,
    String? placa,
    String? tipoVehiculo,
    String? capacidad,
  }) async {
    final body = {
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'password': password,
      'telefono': telefono,
      'rol': rol,
      if (edad != null) 'edad': edad,
      if (cedula != null) 'cedula': cedula,
      if (placa != null) 'placa': placa,
      if (tipoVehiculo != null) 'tipoVehiculo': tipoVehiculo,
      if (capacidad != null) 'capacidad': capacidad,
    };
    final res = await _api.post('/auth/register', body: body);
    await _api.setToken(res['token']);
    await _api.setRefreshToken(res['refreshToken']);
    return User.fromJson(res);
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    await _api.setToken(res['token']);
    await _api.setRefreshToken(res['refreshToken']);
    final prefs = await SharedPreferences.getInstance();
    final user = User.fromJson(res);
    await prefs.setString('userId', user.id);
    await prefs.setString('userEmail', user.email);
    await prefs.setString('userName', '${user.nombre} ${user.apellido}'.trim());
    return user;
  }

  Future<void> logout() async {
    await _api.clearTokens();
  }

  Future<void> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refreshToken');
    if (refresh == null) throw ApiException(401, 'No refresh token');
    final res = await _api.post('/auth/refresh-token', body: {'refreshToken': refresh});
    await _api.setToken(res['token']);
    await _api.setRefreshToken(res['refreshToken']);
  }
}
