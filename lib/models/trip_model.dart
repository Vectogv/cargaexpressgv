import 'package:flutter/material.dart';

import 'location_model.dart';
import 'user_model.dart';

class TripModel {
  final dynamic id;
  final String? estado;
  final LocationModel? origen;
  final LocationModel? destino;
  final String? carga;
  final String? descripcion;
  final num? precioEstimado;
  final num? precioFinal;
  final num? distancia;
  final num? tiempoEstimado;
  final UserModel? cliente;
  final UserModel? conductor;
  final String? createdAt;
  final String? updatedAt;

  TripModel({
    required this.id,
    this.estado,
    this.origen,
    this.destino,
    this.carga,
    this.descripcion,
    this.precioEstimado,
    this.precioFinal,
    this.distancia,
    this.tiempoEstimado,
    this.cliente,
    this.conductor,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive =>
      estado != 'cancelado' &&
      estado != 'finalizado' &&
      estado != 'completado';

  String get estadoLabel {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'aceptado':
        return 'Aceptado';
      case 'en_curso':
        return 'En curso';
      case 'completado':
        return 'Completado';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado ?? 'Desconocido';
    }
  }

  Color get estadoColor {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'aceptado':
        return Colors.blue;
      case 'en_curso':
        return Colors.green;
      case 'completado':
        return Colors.teal;
      case 'finalizado':
        return Colors.grey;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
    id: json['_id'] ?? json['id'],
    estado: json['estado'] as String?,
    origen: json['origen'] != null ? LocationModel.fromJson(json['origen'] as Map<String, dynamic>) : null,
    destino: json['destino'] != null ? LocationModel.fromJson(json['destino'] as Map<String, dynamic>) : null,
    carga: json['carga'] as String?,
    descripcion: json['descripcion'] as String?,
    precioEstimado: json['precioEstimado'] != null ? num.parse(json['precioEstimado'].toString()) : null,
    precioFinal: json['precioFinal'] != null ? num.parse(json['precioFinal'].toString()) : null,
    distancia: json['distancia'] != null ? num.parse(json['distancia'].toString()) : null,
    tiempoEstimado: json['tiempoEstimado'] != null ? num.parse(json['tiempoEstimado'].toString()) : null,
    cliente: json['cliente'] != null ? UserModel.fromJson(json['cliente'] as Map<String, dynamic>) : null,
    conductor: json['conductor'] != null ? UserModel.fromJson(json['conductor'] as Map<String, dynamic>) : null,
    createdAt: json['createdAt'] as String?,
    updatedAt: json['updatedAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    if (estado != null) 'estado': estado,
    if (origen != null) 'origen': origen!.toJson(),
    if (destino != null) 'destino': destino!.toJson(),
    if (carga != null) 'carga': carga,
    if (descripcion != null) 'descripcion': descripcion,
    if (precioEstimado != null) 'precioEstimado': precioEstimado,
    if (precioFinal != null) 'precioFinal': precioFinal,
    if (distancia != null) 'distancia': distancia,
    if (tiempoEstimado != null) 'tiempoEstimado': tiempoEstimado,
    if (cliente != null) 'cliente': cliente!.toJson(),
    if (conductor != null) 'conductor': conductor!.toJson(),
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  TripModel copyWith({
    dynamic id,
    String? estado,
    LocationModel? origen,
    LocationModel? destino,
    String? carga,
    String? descripcion,
    num? precioEstimado,
    num? precioFinal,
    num? distancia,
    num? tiempoEstimado,
    UserModel? cliente,
    UserModel? conductor,
    String? createdAt,
    String? updatedAt,
  }) => TripModel(
    id: id ?? this.id,
    estado: estado ?? this.estado,
    origen: origen ?? this.origen,
    destino: destino ?? this.destino,
    carga: carga ?? this.carga,
    descripcion: descripcion ?? this.descripcion,
    precioEstimado: precioEstimado ?? this.precioEstimado,
    precioFinal: precioFinal ?? this.precioFinal,
    distancia: distancia ?? this.distancia,
    tiempoEstimado: tiempoEstimado ?? this.tiempoEstimado,
    cliente: cliente ?? this.cliente,
    conductor: conductor ?? this.conductor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
