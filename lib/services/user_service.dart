import '../models/user.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api = ApiClient();

  Future<User> getProfile() async {
    final res = await _api.get('/users/profile');
    return User.fromJson(res);
  }

  Future<User> updateProfile({
    String? nombre,
    String? apellido,
    String? email,
    String? telefono,
    int? edad,
  }) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['nombre'] = nombre;
    if (apellido != null) body['apellido'] = apellido;
    if (email != null) body['email'] = email;
    if (telefono != null) body['telefono'] = telefono;
    if (edad != null) body['edad'] = edad;
    final res = await _api.put('/users/profile', body: body);
    return User.fromJson(res);
  }

  Future<String> uploadAvatar(String filePath, {List<int>? bytes, String? filename}) async {
    final res = bytes != null
        ? await _api.uploadBytes('/users/avatar', bytes, filename ?? 'avatar.jpg', 'file')
        : await _api.upload('/users/avatar', filePath, 'file');
    return res['avatar'];
  }
}
