class Trip {
  final String id;
  final String estado;
  final String? clienteId;
  final String? conductorId;
  final String origenDireccion;
  final double origenLat;
  final double origenLng;
  final String destinoDireccion;
  final double destinoLat;
  final double destinoLng;
  final String? carga;
  final double? precioEstimado;
  final double? precioFinal;
  final String? createdAt;
  final String? aceptadoAt;
  final String? enCursoAt;
  final String? completadoAt;
  final String? finalizadoAt;
  final Map<String, dynamic>? cliente;

  Trip({
    required this.id,
    required this.estado,
    this.clienteId,
    this.conductorId,
    required this.origenDireccion,
    required this.origenLat,
    required this.origenLng,
    required this.destinoDireccion,
    required this.destinoLat,
    required this.destinoLng,
    this.carga,
    this.precioEstimado,
    this.precioFinal,
    this.createdAt,
    this.aceptadoAt,
    this.enCursoAt,
    this.completadoAt,
    this.finalizadoAt,
    this.cliente,
  });

  bool get isActive => ['aceptado', 'en_curso'].contains(estado);
  bool get isFinalized => ['finalizado', 'completado'].contains(estado);

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'],
        estado: json['estado'],
        clienteId: json['clienteId'],
        conductorId: json['conductorId'],
        origenDireccion: json['origenDireccion'] ?? json['origen']?['direccion'] ?? '',
        origenLat: (json['origenLat'] ?? json['origen']?['lat'] ?? 0).toDouble(),
        origenLng: (json['origenLng'] ?? json['origen']?['lng'] ?? 0).toDouble(),
        destinoDireccion: json['destinoDireccion'] ?? json['destino']?['direccion'] ?? '',
        destinoLat: (json['destinoLat'] ?? json['destino']?['lat'] ?? 0).toDouble(),
        destinoLng: (json['destinoLng'] ?? json['destino']?['lng'] ?? 0).toDouble(),
        carga: json['carga'] ?? json['descripcion'],
        precioEstimado: json['precioEstimado']?.toDouble(),
        precioFinal: json['precioFinal']?.toDouble(),
        createdAt: json['createdAt'],
        aceptadoAt: json['aceptadoAt'],
        enCursoAt: json['enCursoAt'],
        completadoAt: json['completadoAt'],
        finalizadoAt: json['finalizadoAt'],
        cliente: json['cliente'] is Map ? json['cliente'] as Map<String, dynamic>? : null,
      );

  Map<String, dynamic> toRequest() => {
        'origen': {'direccion': origenDireccion, 'lat': origenLat, 'lng': origenLng},
        'destino': {'direccion': destinoDireccion, 'lat': destinoLat, 'lng': destinoLng},
        if (carga != null) 'descripcion': carga,
      };
}
