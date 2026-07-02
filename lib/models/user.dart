import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class User {
  @JsonKey(name: '_id')
  final String id;
  final String? nombre;
  final String? email;
  final String? rol;
  final String? telefono;
  final double? calificacion;

  User({
    required this.id,
    this.nombre,
    this.email,
    this.rol,
    this.telefono,
    this.calificacion,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
