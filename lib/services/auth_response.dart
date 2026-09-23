class AuthResponse {
  final String token;
  final String? refreshToken;
  final String? id;
  final String? nombre;
  final String? apellido;
  final String? email;
  final String? rol;
  /// Moderador de zona: en el backend es una bandera (`esModerador`) sobre un
  /// usuario con rol cliente/conductor, no un valor de `rol`.
  final bool esModerador;
  final String? zonaModerador;

  AuthResponse({
    required this.token,
    this.refreshToken,
    this.id,
    this.nombre,
    this.apellido,
    this.email,
    this.rol,
    this.esModerador = false,
    this.zonaModerador,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String?,
      id: json['id'] as String?,
      nombre: json['nombre'] as String?,
      apellido: json['apellido'] as String?,
      email: json['email'] as String?,
      rol: json['rol'] as String?,
      esModerador: json['esModerador'] == true,
      zonaModerador: json['zonaModerador'] as String?,
    );
  }
}