class AuthResponse {
  final String token;
  final String refreshToken;
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String rol;

  AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
    );
  }
}
