/// Reglas de validación de usuario iguales a las del backend
/// (`app/validators/auth.ts` y `app/validators/profile.ts`). El backend
/// sigue siendo la validación real; aquí se avisa antes de enviar.
class LimitesUsuario {
  static const int nombre = 100;
  static const int apellido = 100;
  static const int email = 254;
  static const int passwordMin = 6;
  static const int passwordMax = 32;
  static const int telefono = 20;
  static const int cedula = 20;
  static const int placa = 20;
  static const int tipoVehiculo = 50;
  static const int capacidad = 50;
  static const int ciudad = 100;
  static const int edadMin = 18;
  static const int edadMax = 120;
  static const int contactoNombre = 100;
  static const int contactoTelefono = 20;
}

final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final RegExp _telefono = RegExp(r'^\+?[0-9]{7,15}$');

/// null si el correo es válido; si no, el mensaje para el usuario.
String? validarEmail(String valor) {
  final v = valor.trim();
  if (v.isEmpty || v.length > LimitesUsuario.email || !_email.hasMatch(v)) {
    return 'Ingresa un correo electrónico válido';
  }
  return null;
}

/// Teléfono: solo dígitos (con "+" opcional al inicio), 7 a 15 dígitos.
/// Con [opcional] en true, el campo vacío es válido (para el contacto de
/// emergencia, que no siempre se conoce).
String? validarTelefono(String valor, {bool opcional = false}) {
  final v = valor.trim();
  if (v.isEmpty) return opcional ? null : 'El teléfono es obligatorio';
  if (!_telefono.hasMatch(v)) return 'Ingresa un teléfono válido';
  return null;
}

/// Cuerpo de PUT /api/users/profile (app/validators/profile.ts): nombre y
/// apellido vacíos no se envían (no se borran); teléfono y contacto de
/// emergencia vacíos se envían como null (el backend los acepta nulos). El
/// email no se envía: es el usuario de inicio de sesión y no se edita aquí.
/// Lo usan el perfil del cliente y el del conductor.
Map<String, dynamic> cuerpoActualizacionPerfil({
  required String nombre,
  required String apellido,
  required String telefono,
  required String contactoNombre,
  required String contactoTelefono,
}) {
  String? opcional(String v) => v.trim().isEmpty ? null : v.trim();
  return {
    if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
    if (apellido.trim().isNotEmpty) 'apellido': apellido.trim(),
    'telefono': opcional(telefono),
    'contactoEmergenciaNombre': opcional(contactoNombre),
    'contactoEmergenciaTelefono': opcional(contactoTelefono),
  };
}

/// Contraseña al registrarse (el login acepta cualquier longitud).
String? validarPasswordRegistro(String valor) {
  if (valor.length < LimitesUsuario.passwordMin || valor.length > LimitesUsuario.passwordMax) {
    return 'La contraseña debe tener entre ${LimitesUsuario.passwordMin} y ${LimitesUsuario.passwordMax} caracteres';
  }
  return null;
}

/// Edad obligatoria entre 18 y 120.
String? validarEdad(String valor) {
  final v = valor.trim();
  if (v.isEmpty) return 'La edad es obligatoria';
  final edad = int.tryParse(v);
  if (edad == null || edad < LimitesUsuario.edadMin || edad > LimitesUsuario.edadMax) {
    return 'Ingresa una edad válida (${LimitesUsuario.edadMin} a ${LimitesUsuario.edadMax} años)';
  }
  return null;
}
