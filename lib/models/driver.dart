class Driver {
  final String id;
  final String usuarioId;
  final String cedula;
  final String placa;
  final String? fotoConductor;
  final String? fotoVehiculo;
  final bool online;
  final double calificacion;
  final int totalViajes;
  final double horasActivo;
  final double? ultimaUbicacionLat;
  final double? ultimaUbicacionLng;

  Driver({
    required this.id,
    required this.usuarioId,
    required this.cedula,
    required this.placa,
    this.fotoConductor,
    this.fotoVehiculo,
    required this.online,
    this.calificacion = 0.0,
    this.totalViajes = 0,
    this.horasActivo = 0.0,
    this.ultimaUbicacionLat,
    this.ultimaUbicacionLng,
  });

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'],
        usuarioId: json['usuarioId'],
        cedula: json['cedula'] ?? '',
        placa: json['placa'] ?? '',
        fotoConductor: json['fotoConductor'],
        fotoVehiculo: json['fotoVehiculo'],
        online: json['online'] ?? false,
        calificacion: (json['calificacion'] ?? 0.0).toDouble(),
        totalViajes: json['totalViajes'] ?? 0,
        horasActivo: (json['horasActivo'] ?? 0.0).toDouble(),
        ultimaUbicacionLat: json['ultimaUbicacionLat']?.toDouble(),
        ultimaUbicacionLng: json['ultimaUbicacionLng']?.toDouble(),
      );
}

class DriverEarnings {
  final double hoy;
  final double semana;
  final double mes;
  final double total;

  DriverEarnings({required this.hoy, required this.semana, required this.mes, required this.total});

  factory DriverEarnings.fromJson(Map<String, dynamic> json) => DriverEarnings(
        hoy: (json['hoy'] ?? 0).toDouble(),
        semana: (json['semana'] ?? 0).toDouble(),
        mes: (json['mes'] ?? 0).toDouble(),
        total: (json['total'] ?? 0).toDouble(),
      );
}

class DriverStats {
  final int viajes;
  final double horasActivo;
  final double calificacion;

  DriverStats({required this.viajes, required this.horasActivo, required this.calificacion});

  factory DriverStats.fromJson(Map<String, dynamic> json) => DriverStats(
        viajes: json['viajes'] ?? 0,
        horasActivo: (json['horasActivo'] ?? 0).toDouble(),
        calificacion: (json['calificacion'] ?? 0).toDouble(),
      );
}
