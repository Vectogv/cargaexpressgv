class SocketEvents {
  static const String tripStatusChanged = 'trip:status_changed';
  static const String offerAccepted = 'offer:accepted';
  static const String newOffer = 'new:offer';
  static const String driverOnWay = 'driver:on_the_way';
  static const String driverArrived = 'driver:arrived';
  static const String tripStarted = 'trip:started';
  static const String tripFinalized = 'trip:finalized';
  static const String tripCancelled = 'trip:cancelled';
  static const String chatMessage = 'chat:message';
  static const String sosActivated = 'sos:activated';
  static const String paymentConfirmed = 'payment:confirmed';
  static const String paymentRejected = 'payment:rejected';

  /// Conductor: su deuda de comisión venció y la cuenta quedó suspendida
  /// por pago (DriverDebtSuspensionService).
  static const String accountPaymentSuspended = 'account:payment_suspended';

  /// `{tripId, fase, minutos, restanteM, distanciaM, aproximada}`: ETA del
  /// conductor al objetivo de la fase ('recogida' u origen, 'destino'),
  /// calculado por el backend con la ruta real (trip_route_service).
  static const String tripEtaUpdate = 'trip:eta_update';

  /// Igual que [tripEtaUpdate] más `coords` ([[lat, lng], ...]): la ruta que
  /// deben dibujar cliente y conductor. Sólo llega cuando el backend la
  /// recalcula (cambio de fase, desvío o tráfico).
  static const String tripRouteUpdate = 'trip:route_update';

  /// Tickets de soporte (sala del usuario): el staff respondió
  /// (`{ticketId, estado, mensaje: {...}}`) o cambió el estado / tomó el
  /// ticket (`{id, estado, moderador, ...}`).
  static const String ticketMensaje = 'ticket:mensaje';
  static const String ticketEstado = 'ticket:estado';
}
