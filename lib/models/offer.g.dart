// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Offer _$OfferFromJson(Map<String, dynamic> json) => Offer(
  id: json['_id'] as String,
  tripId: json['tripId'] as String?,
  conductor: json['conductor'] == null
      ? null
      : User.fromJson(json['conductor'] as Map<String, dynamic>),
  monto: json['monto'] as num?,
  placa: json['placa'] as String?,
  estado: json['estado'] as String?,
  createdAt: json['createdAt'] as String?,
);

Map<String, dynamic> _$OfferToJson(Offer instance) => <String, dynamic>{
  '_id': instance.id,
  'tripId': instance.tripId,
  'conductor': instance.conductor?.toJson(),
  'monto': instance.monto,
  'placa': instance.placa,
  'estado': instance.estado,
  'createdAt': instance.createdAt,
};
