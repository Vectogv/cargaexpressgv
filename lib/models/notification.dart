class AppNotification {
  final String id;
  final String tipo;
  final String titulo;
  final String? mensaje;
  final bool leido;
  final String? createdAt;

  AppNotification({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.mensaje,
    this.leido = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'],
        tipo: json['tipo'],
        titulo: json['titulo'],
        mensaje: json['mensaje'],
        leido: json['leido'] ?? false,
        createdAt: json['createdAt'],
      );
}
