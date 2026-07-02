import 'package:json_annotation/json_annotation.dart';
import 'user.dart';
import 'location_model.dart';

part 'trip.g.dart';

@JsonSerializable(explicitToJson: true)
class Trip {
  @JsonKey(name: '_id')
  final String id;
  final String? estado;
  final LocationModel? origen;
  final LocationModel? destino;
  final String? carga;
  final String? descripcion;
  final num? precioEstimado;
  final num? precioFinal;
  final num? distancia;
  final num? tiempoEstimado;
  final User? cliente;
  final User? conductor;
  final String? createdAt;
  final String? updatedAt;

  Trip({
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

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);
  Map<String, dynamic> toJson() => _$TripToJson(this);
}
