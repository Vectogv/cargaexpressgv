import 'package:flutter/material.dart';

import '../contracts/trip_status.dart';
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
      estado != TripStatus.cancelado &&
      estado != TripStatus.finalizado &&
      estado != TripStatus.rechazado;

  String get estadoLabel {
    switch (estado) {
      case TripStatus.creado:
        return 'Creado';
      case TripStatus.buscando:
        return 'Buscando conductor';
      case TripStatus.pendiente:
        return 'Pendiente';
      case TripStatus.aceptado:
        return 'Aceptado';
      case TripStatus.enCamino:
        return 'Conductor en camino';
      case TripStatus.llegada:
        return 'Conductor llegó';
      case TripStatus.enCurso:
        return 'En curso';
      case TripStatus.entregado:
        return 'Entregado';
      case TripStatus.esperaConfirmacion:
        return 'Esperando confirmación';
      case TripStatus.finalizado:
        return 'Finalizado';
      case TripStatus.cancelado:
        return 'Cancelado';
      case TripStatus.rechazado:
        return 'Rechazado';
      case TripStatus.disputa:
        return 'En disputa';
      case TripStatus.sos:
        return 'Emergencia';
      default:
        return estado ?? 'Desconocido';
    }
  }

  Color get estadoColor {
    switch (estado) {
      case TripStatus.creado:
        return Colors.indigo;
      case TripStatus.buscando:
        return Colors.deepPurple;
      case TripStatus.pendiente:
        return Colors.orange;
      case TripStatus.aceptado:
        return Colors.blue;
      case TripStatus.enCamino:
        return Colors.lightBlue;
      case TripStatus.llegada:
        return Colors.cyan;
      case TripStatus.enCurso:
        return Colors.green;
      case TripStatus.entregado:
        return Colors.teal;
      case TripStatus.esperaConfirmacion:
        return Colors.amber;
      case TripStatus.finalizado:
        return Colors.grey;
      case TripStatus.cancelado:
        return Colors.red;
      case TripStatus.rechazado:
        return Colors.deepOrange;
      case TripStatus.disputa:
        return Colors.purple;
      case TripStatus.sos:
        return Colors.redAccent;
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
