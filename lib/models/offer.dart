import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'offer.g.dart';

@JsonSerializable(explicitToJson: true)
class Offer {
  @JsonKey(name: '_id')
  final String id;
  final String? tripId;
  final User? conductor;
  final num? monto;
  final String? placa;
  final String? estado;
  final String? createdAt;

  Offer({
    required this.id,
    this.tripId,
    this.conductor,
    this.monto,
    this.placa,
    this.estado,
    this.createdAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) => _$OfferFromJson(json);
  Map<String, dynamic> toJson() => _$OfferToJson(this);
}
