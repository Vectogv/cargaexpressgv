class TripStatus {
  static const String creado = 'creado';
  // Reserva programada creada por el cliente: estado previo a la búsqueda de
  // conductor. La app lo trata como un viaje "en espera" (no activo).
  static const String reservado = 'reservado';
  static const String buscando = 'buscando_conductor';
  static const String pendiente = 'pendiente';
  static const String aceptado = 'aceptado';
  static const String enCamino = 'conductor_en_camino';
  static const String llegada = 'conductor_llegada';
  static const String enCurso = 'en_curso';
  static const String entregado = 'entregado';
  static const String esperaConfirmacion = 'esperando_confirmacion';
  static const String pendienteConfirmacion = 'pendiente_confirmacion';
  static const String finalizado = 'finalizado';
  static const String cancelado = 'cancelado';
  static const String rechazado = 'rechazado';
  static const String disputa = 'disputa';
  static const String enDisputa = 'en_disputa';
  static const String sos = 'sos';

  /// Etiqueta legible en español para cualquier estado del backend
  /// (`app/services/trip_status_labels.ts`). Nunca devuelve el string crudo de
  /// un estado conocido; para uno desconocido devuelve el valor tal cual.
  static String label(String? estado) {
    switch (estado) {
      case creado: return 'Solicitud creada';
      case reservado: return 'Reserva programada';
      case buscando: return 'Buscando conductor';
      case pendiente: return 'Oferta pendiente';
      case aceptado: return 'Conductor asignado';
      case enCamino: return 'Conductor en camino';
      case llegada: return 'Conductor llegó';
      case enCurso: return 'En camino a destino';
      case entregado: return 'Carga entregada';
      case esperaConfirmacion:
      case pendienteConfirmacion: return 'Pendiente de tu confirmación';
      case finalizado: return 'Finalizado';
      case cancelado: return 'Cancelado';
      case rechazado: return 'Rechazado';
      case disputa:
      case enDisputa: return 'En disputa';
      case sos: return 'Emergencia (SOS) activa';
      default: return estado ?? '';
    }
  }
}
