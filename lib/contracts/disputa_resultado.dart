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
