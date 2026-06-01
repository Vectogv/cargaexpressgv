class Oferta {
  final String id;
  final String viajeId;
  final double monto;
  final String? estado;
  final String? createdAt;
  final Map<String, dynamic> conductor;

  Oferta({
    required this.id,
    required this.viajeId,
    required this.monto,
    this.estado,
    this.createdAt,
    required this.conductor,
  });

  factory Oferta.fromJson(Map<String, dynamic> json) => Oferta(
        id: json['id'],
        viajeId: json['viajeId'] ?? '',
        monto: (json['monto'] ?? 0).toDouble(),
        estado: json['estado'],
        createdAt: json['createdAt'],
        conductor: json['conductor'] as Map<String, dynamic>? ?? {},
      );
}
