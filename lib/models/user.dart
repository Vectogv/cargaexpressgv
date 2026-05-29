class User {
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String? telefono;
  final int? edad;
  final String? avatar;
  final String rol;

  User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    this.telefono,
    this.edad,
    this.avatar,
    required this.rol,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        nombre: json['nombre'],
        apellido: json['apellido'],
        email: json['email'],
        telefono: json['telefono'],
        edad: json['edad'],
        avatar: json['avatar'],
        rol: json['rol'],
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'telefono': telefono,
        'edad': edad,
      };

  String get iniciales =>
      '${nombre.isNotEmpty ? nombre[0] : ''}${apellido.isNotEmpty ? apellido[0] : ''}';
}
