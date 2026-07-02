// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['_id'] as String,
  nombre: json['nombre'] as String?,
  email: json['email'] as String?,
  rol: json['rol'] as String?,
  telefono: json['telefono'] as String?,
  calificacion: (json['calificacion'] as num?)?.toDouble(),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  '_id': instance.id,
  'nombre': instance.nombre,
  'email': instance.email,
  'rol': instance.rol,
  'telefono': instance.telefono,
  'calificacion': instance.calificacion,
};
