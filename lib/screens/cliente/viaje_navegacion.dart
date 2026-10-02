import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/navegador_global.dart';
import '../../services/api_client.dart';
import '../conductor/mis_reservas_screen.dart';
import 'rastreo_screen.dart';
import 'viaje_detalle_screen.dart';

/// Estados en los que el viaje ya no se sigue en el mapa: se abre el detalle.
const _estadosCerrados = {'finalizado', 'cancelado', 'disputa', 'reservado'};

/// Abre el viaje al tocar su push (`viaje_estado`, `viaje_cancelado`,
/// `disputa_resuelta`, `reserva`) sin `BuildContext`. Cliente: rastreo o
/// detalle. Conductor: solo una reserva (`reservado`) abre "Mis reservas"; su
/// viaje activo ya lo abre el inicio al detectarlo. Vuelve al inicio antes de
/// abrir, para no apilar un segundo rastreo. Si el navegador raíz aún no existe
/// (la app arranca desde la notificación), reintenta unos segundos.
void abrirViajeGlobal(String viajeId, {int intentos = 20}) {
  final rol = ApiClient.instance.rol;
  if (ApiClient.instance.token == null || (rol != 'cliente' && rol != 'conductor')) return;
  final nav = navegadorGlobal.currentState;
  if (nav == null) {
    if (intentos <= 0) return;
    Timer(const Duration(milliseconds: 500), () => abrirViajeGlobal(viajeId, intentos: intentos - 1));
    return;
  }
  unawaited(_abrir(nav, viajeId, conductor: rol == 'conductor'));
}

Future<void> _abrir(NavigatorState nav, String viajeId, {required bool conductor}) async {
  String? estado;
  try {
    estado = (await ApiClient.instance.getTripDetail(viajeId))['estado']?.toString();
  } catch (_) {
    // Sin red: el detalle muestra su propio error con "Reintentar".
  }
  if (!nav.mounted) return;
  if (conductor) {
    if (estado != 'reservado') return;
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => const MisReservasScreen()));
    return;
  }
  nav.popUntil((r) => r.isFirst);
  final activo = estado != null && !_estadosCerrados.contains(estado);
  nav.push(MaterialPageRoute(
    builder: (_) => activo ? const RastreoScreen() : ViajeDetalleScreen(tripId: viajeId),
  ));
}
