import 'user_model.dart';

class OfferModel {
  final dynamic id;
  final dynamic tripId;
  final UserModel? conductor;
  final num? monto;
  final String? placa;
  final String? estado;
  final String? createdAt;

  OfferModel({
    required this.id,
    required this.tripId,
    this.conductor,
    this.monto,
    this.placa,
    this.estado,
    this.createdAt,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) => OfferModel(
    id: json['_id'] ?? json['id'],
    tripId: json['tripId'] ?? json['viaje'],
    conductor: json['conductor'] != null ? UserModel.fromJson(json['conductor'] as Map<String, dynamic>) : null,
    monto: json['monto'] != null ? num.parse(json['monto'].toString()) : null,
    placa: json['placa'] as String?,
    estado: json['estado'] as String?,
    createdAt: json['createdAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'tripId': tripId,
    if (conductor != null) 'conductor': conductor!.toJson(),
    if (monto != null) 'monto': monto,
    if (placa != null) 'placa': placa,
    if (estado != null) 'estado': estado,
    if (createdAt != null) 'createdAt': createdAt,
  };

  OfferModel copyWith({
    dynamic id,
    dynamic tripId,
    UserModel? conductor,
    num? monto,
    String? placa,
    String? estado,
    String? createdAt,
  }) => OfferModel(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    conductor: conductor ?? this.conductor,
    monto: monto ?? this.monto,
    placa: placa ?? this.placa,
    estado: estado ?? this.estado,
    createdAt: createdAt ?? this.createdAt,
  );
}
