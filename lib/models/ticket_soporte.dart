/// Ticket de soporte y su hilo de mensajes, según
/// `docs/TICKETS_SOPORTE_API.md` del backend (`/api/support/tickets`).
///
/// Los adjuntos llegan como ruta relativa firmada (`/storage/uploads/...?exp=&sig=`,
/// vigencia 1 h): la UI los resuelve con `resolveMediaUrl`.
class TicketSoporte {
  static const List<String> categorias = ['pago', 'viaje', 'cuenta', 'app', 'otro'];

  /// Estados que se muestran en el filtro "Activos".
  static const List<String> estadosActivos = ['abierto', 'en_proceso', 'resuelto'];

  final String id;
  final String categoria;
  final String asunto;
  final String descripcion;
  final String? adjunto;
  final String estado;
  final String? viajeId;
  final Map<String, dynamic>? viaje;
  final String? moderadorNombre;
  final int totalMensajes;
  final DateTime? ultimoMensajeAt;
  final DateTime? createdAt;
  final DateTime? cerradoAt;
  final List<MensajeTicket> mensajes;

  const TicketSoporte({
    required this.id,
    required this.categoria,
    required this.asunto,
    required this.descripcion,
    required this.estado,
    this.adjunto,
    this.viajeId,
    this.viaje,
    this.moderadorNombre,
    this.totalMensajes = 0,
    this.ultimoMensajeAt,
    this.createdAt,
    this.cerradoAt,
    this.mensajes = const [],
  });

  bool get cerrado => estado == 'cerrado';

  /// Última actividad: el último mensaje o, si no hay, la creación.
  DateTime? get ultimaActividad => ultimoMensajeAt ?? createdAt;

  factory TicketSoporte.fromJson(Map<String, dynamic> json) {
    final moderador = json['moderador'];
    final viaje = json['viaje'];
    final mensajes = json['mensajes'];
    return TicketSoporte(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      categoria: json['categoria']?.toString() ?? 'otro',
      asunto: json['asunto']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      adjunto: _texto(json['adjunto']),
      estado: json['estado']?.toString() ?? 'abierto',
      viajeId: _texto(json['viajeId'] ?? (viaje is Map ? viaje['id'] : null)),
      viaje: viaje is Map ? Map<String, dynamic>.from(viaje) : null,
      moderadorNombre: moderador is Map ? _texto(moderador['nombre']) : null,
      totalMensajes: _entero(json['totalMensajes']) ?? (mensajes is List ? mensajes.length : 0),
      ultimoMensajeAt: _fecha(json['ultimoMensajeAt']),
      createdAt: _fecha(json['createdAt']),
      cerradoAt: _fecha(json['cerradoAt']),
      mensajes: mensajes is List
          ? mensajes.whereType<Map>().map((m) => MensajeTicket.fromJson(Map<String, dynamic>.from(m))).toList()
          : const [],
    );
  }

  TicketSoporte copyWith({
    String? estado,
    String? moderadorNombre,
    int? totalMensajes,
    DateTime? ultimoMensajeAt,
    DateTime? cerradoAt,
    List<MensajeTicket>? mensajes,
  }) {
    return TicketSoporte(
      id: id,
      categoria: categoria,
      asunto: asunto,
      descripcion: descripcion,
      adjunto: adjunto,
      estado: estado ?? this.estado,
      viajeId: viajeId,
      viaje: viaje,
      moderadorNombre: moderadorNombre ?? this.moderadorNombre,
      totalMensajes: totalMensajes ?? this.totalMensajes,
      ultimoMensajeAt: ultimoMensajeAt ?? this.ultimoMensajeAt,
      createdAt: createdAt,
      cerradoAt: cerradoAt ?? this.cerradoAt,
      mensajes: mensajes ?? this.mensajes,
    );
  }

  static String etiquetaEstado(String estado) {
    switch (estado) {
      case 'abierto':
        return 'Abierto';
      case 'en_proceso':
        return 'En proceso';
      case 'resuelto':
        return 'Resuelto';
      case 'cerrado':
        return 'Cerrado';
      default:
        return estado;
    }
  }

  static String etiquetaCategoria(String categoria) {
    switch (categoria) {
      case 'pago':
        return 'Pagos';
      case 'viaje':
        return 'Viaje';
      case 'cuenta':
        return 'Cuenta';
      case 'app':
        return 'La app';
      case 'otro':
        return 'Otro';
      default:
        return categoria;
    }
  }
}

class MensajeTicket {
  final String id;
  final String? autorNombre;
  final String? autorAvatar;

  /// `usuario | moderador | admin`.
  final String rolAutor;
  final String mensaje;
  final String? adjunto;
  final DateTime? createdAt;

  /// Estado local mientras se envía (`sending`, `failed`); null si ya está
  /// guardado en el backend.
  final String? estadoLocal;

  const MensajeTicket({
    required this.id,
    required this.rolAutor,
    required this.mensaje,
    this.autorNombre,
    this.autorAvatar,
    this.adjunto,
    this.createdAt,
    this.estadoLocal,
  });

  /// Escrito por el cliente/conductor dueño del ticket.
  bool get esDelUsuario => rolAutor == 'usuario';

  /// Nombre que se muestra sobre la burbuja del staff.
  String get nombreParaMostrar {
    final n = autorNombre?.trim();
    if (n != null && n.isNotEmpty) return n;
    return rolAutor == 'admin' ? 'Administrador' : 'Soporte';
  }

  factory MensajeTicket.fromJson(Map<String, dynamic> json) {
    final autor = json['autor'];
    return MensajeTicket(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      autorNombre: autor is Map ? _texto(autor['nombre']) : null,
      autorAvatar: autor is Map ? _texto(autor['avatar']) : null,
      rolAutor: json['rolAutor']?.toString() ?? 'usuario',
      mensaje: json['mensaje']?.toString() ?? '',
      adjunto: _texto(json['adjunto']),
      createdAt: _fecha(json['createdAt']),
    );
  }

  MensajeTicket copyWith({String? id, String? estadoLocal, String? adjunto, bool limpiarEstadoLocal = false}) {
    return MensajeTicket(
      id: id ?? this.id,
      autorNombre: autorNombre,
      autorAvatar: autorAvatar,
      rolAutor: rolAutor,
      mensaje: mensaje,
      adjunto: adjunto ?? this.adjunto,
      createdAt: createdAt,
      estadoLocal: limpiarEstadoLocal ? null : (estadoLocal ?? this.estadoLocal),
    );
  }
}

String? _texto(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _entero(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

DateTime? _fecha(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}
