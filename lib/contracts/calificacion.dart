/// Calificación de un conductor tal como la ve el cliente.
///
/// El backend guarda `conductores.calificacion` como decimal con valor por
/// defecto 0 (puede llegar como número, como texto "0.0" o null) y
/// `total_viajes` en 0 para un conductor sin viajes. Un conductor sin
/// calificaciones se muestra como "Nuevo", nunca como "0.0".
String etiquetaCalificacion(Object? valor, {Object? totalViajes}) {
  final viajes = _numero(totalViajes);
  if (viajes != null && viajes <= 0) return 'Nuevo';
  final n = _numero(valor);
  if (n == null || n <= 0) return 'Nuevo';
  return n.toStringAsFixed(1);
}

/// [etiquetaCalificacion] leyendo el mapa del conductor de cualquier payload
/// (`rating` en ofertas/socket, `calificacion` en el viaje).
String etiquetaCalificacionConductor(Map<String, dynamic>? conductor) {
  if (conductor == null) return 'Nuevo';
  return etiquetaCalificacion(
    conductor['rating'] ?? conductor['calificacion'],
    totalViajes: conductor['totalViajes'] ?? conductor['total_viajes'],
  );
}

double? _numero(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v.trim());
  return null;
}
