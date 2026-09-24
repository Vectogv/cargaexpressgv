/// Resultado de una disputa tal como lo guarda el backend
/// (`admin_controller.ts` resolve: `favor_conductor` | `favor_cliente`).
class DisputaResultado {
  static const String favorConductor = 'favor_conductor';
  static const String favorCliente = 'favor_cliente';
}

/// Texto legible del resultado de una disputa. Nunca muestra el valor crudo.
String etiquetaResultado(dynamic resultado) {
  switch (resultado?.toString()) {
    case DisputaResultado.favorCliente:
      return 'A favor del cliente';
    case DisputaResultado.favorConductor:
      return 'A favor del conductor';
    case null:
    case '':
      return 'Sin resultado';
    default:
      return 'Disputa resuelta';
  }
}

/// Texto legible del motivo de la disputa. El backend guarda un código cuando
/// la abre el sistema (`trip_controller.ts`: `cliente_rechaza_cierre`;
/// `moderator_controller.ts`: `cierre_sin_confirmar`) o el texto que escribió
/// la persona; nunca se muestra el código crudo.
String etiquetaProblemaDisputa(dynamic problema) {
  final p = problema?.toString().trim() ?? '';
  switch (p) {
    case '':
      return '—';
    case 'cliente_rechaza_cierre':
      return 'Rechazaste la entrega';
    case 'cierre_sin_confirmar':
      return 'El cierre del viaje no se confirmó a tiempo';
    default:
      return p;
  }
}

/// Qué significa la decisión para el cliente (lo que hace el backend al
/// resolver: a favor del cliente el viaje queda cancelado sin cobro; a favor
/// del conductor puede quedar un acuerdo de pago que se ve en Pagos).
String consecuenciaParaCliente(dynamic resultado) {
  switch (resultado?.toString()) {
    case DisputaResultado.favorCliente:
      return 'El viaje quedó cancelado y no se te cobra.';
    case DisputaResultado.favorConductor:
      return 'Se reconoció el servicio del conductor. Si quedó un pago pendiente, lo verás en Pagos.';
    default:
      return '';
  }
}
