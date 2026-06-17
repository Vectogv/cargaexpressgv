class UserModel {
  final String id;
  final String? nombre;
  final String? apellido;
  final String? email;
  final String? rol;
  final String? telefono;
  final double? calificacion;

  UserModel({
    required this.id,
    this.nombre,
    this.apellido,
    this.email,
    this.rol,
    this.telefono,
    this.calificacion,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['_id'] as String? ?? json['id'] as String? ?? '',
    nombre: json['nombre'] as String?,
    apellido: json['apellido'] as String?,
    email: json['email'] as String?,
    rol: json['rol'] as String?,
    telefono: json['telefono'] as String?,
    calificacion: json['calificacion'] != null ? double.parse(json['calificacion'].toString()) : null,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    if (nombre != null) 'nombre': nombre,
    if (apellido != null) 'apellido': apellido,
    if (email != null) 'email': email,
    if (rol != null) 'rol': rol,
    if (telefono != null) 'telefono': telefono,
    if (calificacion != null) 'calificacion': calificacion,
  };

  UserModel copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? email,
    String? rol,
    String? telefono,
    double? calificacion,
  }) => UserModel(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    apellido: apellido ?? this.apellido,
    email: email ?? this.email,
    rol: rol ?? this.rol,
    telefono: telefono ?? this.telefono,
    calificacion: calificacion ?? this.calificacion,
  );
}
