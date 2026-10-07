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
  final String? fotoEntrega;
  /// Inicio real del viaje (start-trip) según el backend: el cronómetro del
  /// conductor cuenta desde aquí y no desde que se abrió la pantalla.
  final String? enCursoAt;
  /// 'inmediata' o 'programada' (reserva). null en respuestas viejas = inmediata.
  final String? tipoProgramacion;
  /// Fecha y hora programadas de una reserva ('YYYY-MM-DD' / 'HH:mm'), null si es inmediata.
  final String? fechaProgramada;
  final String? horaProgramada;
  /// PIN de 4 dígitos para cerrar la entrega cerca del destino. Sólo lo ve el
  /// cliente (el backend siempre manda null al conductor); null en viajes
  /// viejos, que cierran sin pedirlo.
  final String? pinEntrega;
  /// Quién recibe la carga en el destino (opcionales, los llena el cliente).
  final String? receptorNombre;
  final String? receptorTelefono;
  /// Vehículo que el cliente pidió para este envío (informativo: no oculta
  /// el viaje a conductores con otro vehículo). null si no especificó.
  final String? tipoVehiculoRequerido;
  /// Escalera de acompañamiento mientras se busca conductor (lo arma el
  /// servidor): `{etapa, mensaje, precioSugerido: {min, max}|null, cierreHasta}`.
  /// null fuera de la búsqueda o en respuestas viejas.
  final Map<String, dynamic>? busqueda;

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
    this.fotoEntrega,
    this.enCursoAt,
    this.tipoProgramacion,
    this.fechaProgramada,
    this.horaProgramada,
    this.pinEntrega,
    this.receptorNombre,
    this.receptorTelefono,
    this.tipoVehiculoRequerido,
    this.busqueda,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('_id') && json.containsKey('id')) {
      json = <String, dynamic>{...json, '_id': json['id']};
    }
    return _$TripFromJson(json);
  }
  Map<String, dynamic> toJson() => _$TripToJson(this);

  /// Fusiona un payload de socket (normalmente parcial: `{id, estado, ...}`)
  /// sobre el viaje actual serializado, sin perder datos ya cargados.
  ///
  /// - Un `conductor`/`cliente` anidado entrante se fusiona campo a campo con
  ///   el existente (no lo reemplaza): un objeto parcial o sin `_id` no borra
  ///   el nombre, teléfono, etc. que ya se tenía.
  /// - Los valores `null` entrantes no pisan datos existentes.
  static Map<String, dynamic> mergeSocketPayload(
    Map<String, dynamic> base,
    Map<String, dynamic> data,
  ) {
    final merged = <String, dynamic>{...base};
    data.forEach((key, value) {
      if (value == null) return;
      if ((key == 'conductor' || key == 'cliente') && value is Map) {
        final incoming = Map<String, dynamic>.from(value);
        final existing = merged[key];
        final nested = existing is Map
            ? <String, dynamic>{...Map<String, dynamic>.from(existing)}
            : <String, dynamic>{};
        incoming.forEach((k, v) {
          if (v != null) nested[k] = v;
        });
        nested['_id'] ??= incoming['id'];
        merged[key] = nested;
        return;
      }
      merged[key] = key == '_id' ? value.toString() : value;
    });
    return merged;
  }
}
