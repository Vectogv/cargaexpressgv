import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navegador_global.dart';
import '../../../services/api_client.dart';
import 'ticket_detalle_screen.dart';

/// Abre el detalle de un ticket de soporte sin `BuildContext` (toque de un
/// push `ticket_mensaje` / `ticket_estado`). Si el navegador raíz aún no
/// existe (la app está arrancando desde la notificación), reintenta durante
/// unos segundos. Sin sesión no hace nada.
void abrirTicketSoporteGlobal(String ticketId, {int intentos = 20}) {
  if (ApiClient.instance.token == null) return;
  final nav = navegadorGlobal.currentState;
  if (nav == null) {
    if (intentos <= 0) return;
    Timer(const Duration(milliseconds: 500), () => abrirTicketSoporteGlobal(ticketId, intentos: intentos - 1));
    return;
  }
  nav.push(MaterialPageRoute(builder: (_) => TicketDetalleScreen(ticketId: ticketId)));
}
