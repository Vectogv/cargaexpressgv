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
  // Datos del conductor que envía el backend en el viaje
  // (`TripController.formatViajeResponse`): se muestran en el rastreo.
  final String? placa;
  final String? tipoVehiculo;
  final num? totalViajes;

  User({
    required this.id,
    this.nombre,
    this.email,
    this.rol,
    this.telefono,
    this.calificacion,
    this.placa,
    this.tipoVehiculo,
    this.totalViajes,
  });

  /// El backend a veces envía el usuario anidado con `id` en vez de `_id`
  /// (p. ej. payloads de socket) o con id numérico. Se normaliza antes de
  /// delegar en el código generado para que no lance `TypeError` y para que
  /// el arreglo sobreviva a una regeneración de `user.g.dart`.
  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['_id'] ?? json['id'];
    if (json['_id'] is! String) {
      json = <String, dynamic>{...json, '_id': rawId?.toString() ?? ''};
    }
    // Columna decimal: el backend puede enviarla como texto ("4.50").
    final cal = json['calificacion'];
    if (cal != null && cal is! num) {
      json = <String, dynamic>{...json, 'calificacion': double.tryParse(cal.toString())};
    }
    final total = json['totalViajes'];
    if (total != null && total is! num) {
      json = <String, dynamic>{...json, 'totalViajes': num.tryParse(total.toString())};
    }
    for (final k in const ['placa', 'tipoVehiculo']) {
      final v = json[k];
      if (v != null && v is! String) json = <String, dynamic>{...json, k: v.toString()};
    }
    return _$UserFromJson(json);
  }
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
