/// Oferta del conductor que sigue esperando respuesta del cliente
/// (GET /api/drivers/offers).
class OfertaPendiente {
  final String id;
  final String viajeId;
  final num monto;

  /// Vencimiento según el servidor (null si el backend no lo informa).
  final DateTime? expiresAt;
  final String origen;
  final String destino;

  const OfertaPendiente({
    required this.id,
    required this.viajeId,
    required this.monto,
    required this.expiresAt,
    required this.origen,
    required this.destino,
  });

  factory OfertaPendiente.fromJson(Map<String, dynamic> json) {
    final viaje = json['viaje'] is Map ? Map<String, dynamic>.from(json['viaje'] as Map) : const <String, dynamic>{};
    String direccion(dynamic lugar) =>
        lugar is Map ? (lugar['direccion']?.toString() ?? '') : (lugar?.toString() ?? '');
    final monto = json['monto'];
    return OfertaPendiente(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      viajeId: (json['viajeId'] ?? json['tripId'])?.toString() ?? '',
      monto: monto is num ? monto : num.tryParse(monto?.toString() ?? '') ?? 0,
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      origen: direccion(viaje['origen']),
      destino: direccion(viaje['destino']),
    );
  }

  /// Tiempo que le queda a la oferta respecto a [ahoraServidor] (nunca
  /// negativo). Null si no se conoce el vencimiento.
  Duration? restante(DateTime ahoraServidor) {
    final vence = expiresAt;
    if (vence == null) return null;
    final r = vence.difference(ahoraServidor);
    return r.isNegative ? Duration.zero : r;
  }

  /// `true` si el evento de socket (`offer:*`, con `ofertaId`/`viajeId`) se
  /// refiere a esta oferta.
  bool coincideCon(Map<String, dynamic> evento) {
    final ofertaId = (evento['ofertaId'] ?? evento['offerId'])?.toString();
    if (ofertaId != null && ofertaId.isNotEmpty) return ofertaId == id;
    final viaje = (evento['viajeId'] ?? evento['tripId'])?.toString();
    return viaje != null && viaje == viajeId;
  }
}

/// `m:ss` para una cuenta regresiva.
String formatoCuentaRegresiva(Duration d) {
  final segundos = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = segundos ~/ 60;
  final s = (segundos % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
