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

  /// `{minutos}`: ETA del conductor al origen mientras el viaje está
  /// aceptado (driver_controller.updateLocation, 30 km/h).
  static const String tripEtaUpdate = 'trip:eta_update';
}
