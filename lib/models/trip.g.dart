// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Trip _$TripFromJson(Map<String, dynamic> json) => Trip(
  id: json['_id'] as String,
  estado: json['estado'] as String?,
  origen: json['origen'] == null
      ? null
      : LocationModel.fromJson(json['origen'] as Map<String, dynamic>),
  destino: json['destino'] == null
      ? null
      : LocationModel.fromJson(json['destino'] as Map<String, dynamic>),
  carga: json['carga'] as String?,
  descripcion: json['descripcion'] as String?,
  precioEstimado: json['precioEstimado'] as num?,
  precioFinal: json['precioFinal'] as num?,
  distancia: json['distancia'] as num?,
  tiempoEstimado: json['tiempoEstimado'] as num?,
  cliente: json['cliente'] == null
      ? null
      : User.fromJson(json['cliente'] as Map<String, dynamic>),
  conductor: json['conductor'] == null
      ? null
      : User.fromJson(json['conductor'] as Map<String, dynamic>),
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$TripToJson(Trip instance) => <String, dynamic>{
  '_id': instance.id,
  'estado': instance.estado,
  'origen': instance.origen?.toJson(),
  'destino': instance.destino?.toJson(),
  'carga': instance.carga,
  'descripcion': instance.descripcion,
  'precioEstimado': instance.precioEstimado,
  'precioFinal': instance.precioFinal,
  'distancia': instance.distancia,
  'tiempoEstimado': instance.tiempoEstimado,
  'cliente': instance.cliente?.toJson(),
  'conductor': instance.conductor?.toJson(),
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};
