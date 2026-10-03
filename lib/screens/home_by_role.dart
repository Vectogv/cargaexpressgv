import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import '../services/api_client.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../services/session_monitor_service.dart';
import 'admin/dashboard_screen.dart';
import 'cliente/home_screen.dart';
import 'conductor/home_screen.dart' as conductor;
import 'moderador/moderador_home_screen.dart';
import 'user/auth_screen.dart';

/// Destino de inicio de cada rol. Única fuente de verdad: la usan el login,
/// el registro y la recuperación de sesión en `main.dart`, para que un mismo
/// usuario vea siempre la misma pantalla de inicio.
/// [otraApp]: la cuenta es de un rol que vive en la otra app (ver [appFlavor]).
enum HomeDestino { admin, moderador, conductor, cliente, ninguno, otraApp }

/// Son dos apps del mismo código (`--flavor cliente` / `--flavor conductor`).
/// La del cliente solo deja entrar clientes; la del conductor, conductores
/// (líderes incluidos), moderadores y admin. Sin flavor (pruebas) entran todos.
bool get esAppCliente => appFlavor == 'cliente';
bool get esAppConductor => appFlavor == 'conductor';

/// Mensaje para [HomeDestino.otraApp] y [HomeDestino.ninguno]; null si el
/// destino tiene pantalla en esta app.
String? errorDeDestino(HomeDestino d) => switch (d) {
      HomeDestino.otraApp => esAppCliente
          ? 'Esta cuenta es de conductor. Entra desde la app CargaExpress Conductor.'
          : 'Esta cuenta es de cliente. Entra desde la app CargaExpress.',
      HomeDestino.ninguno => 'Tu cuenta no tiene un rol habilitado en la app. Contacta a soporte.',
      _ => null,
    };

/// El moderador en el backend es la bandera `esModerador` sobre un usuario
/// cliente/conductor (no un valor de `rol`); se acepta también
/// `rol == 'moderador'` por compatibilidad. Un admin siempre va al panel de
/// administración aunque tenga la bandera. En la app del cliente se ignora la
/// bandera: un moderador que también es cliente entra como cliente.
HomeDestino homeDestinoFor({String? rol, bool esModerador = false}) {
  final d = _destinoPorRol(rol, esModerador && !esAppCliente);
  if (d == HomeDestino.ninguno) return d;
  if (esAppCliente && d != HomeDestino.cliente) return HomeDestino.otraApp;
  if (esAppConductor && d == HomeDestino.cliente) return HomeDestino.otraApp;
  return d;
}

HomeDestino _destinoPorRol(String? rol, bool esModerador) {
  if (rol == 'admin') return HomeDestino.admin;
  if (esModerador || rol == 'moderador') return HomeDestino.moderador;
  switch (rol) {
    case 'conductor':
      return HomeDestino.conductor;
    case 'cliente':
      return HomeDestino.cliente;
    default:
      return HomeDestino.ninguno;
  }
}

/// Pantalla de inicio para un destino. [HomeDestino.ninguno] (rol
/// desconocido) vuelve al login.
Widget homeScreenFor(HomeDestino destino) {
  switch (destino) {
    case HomeDestino.admin:
      return const DashboardScreen();
    case HomeDestino.moderador:
      return const ModeradorHomeScreen();
    case HomeDestino.conductor:
      return const conductor.HomeScreen();
    case HomeDestino.cliente:
      return const ClienteHomeScreen();
    case HomeDestino.ninguno:
    case HomeDestino.otraApp:
      return const AuthScreen();
  }
}

/// Destino de la sesión guardada en [ApiClient].
HomeDestino homeDestinoForSession() => homeDestinoFor(
      rol: ApiClient.instance.rol,
      esModerador: ApiClient.instance.esModerador,
    );

/// Monitor de sesión (idempotente) y registro del token FCM, que `main.dart`
/// sólo hace si al abrir la app ya había sesión guardada.
void iniciarServiciosDeSesion() {
  SessionMonitorService.instance.start();
  unawaited(NotificationService.instance.registrarTokenSesion().catchError((Object e) {
    LoggerService.instance.error('registrarTokenSesion error', e);
  }));
}

/// Abre [home] comoúnica ruta de la pila. Se usa tras login y registro:
/// antes quedaba debajo la pantalla de autenticación, y cualquier
/// `popUntil((r) => r.isFirst)` (cancelar viaje, volver al inicio...)
/// llevaba a ella, como si se hubiera cerrado la sesión.
///
/// También inicia los servicios de sesión que `main.dart` sólo arranca si
/// al abrir la app ya había un token guardado.
Future<void> abrirInicioComoRaiz(BuildContext context, Widget home) {
  iniciarServiciosDeSesion();
  return Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => home),
    (_) => false,
  );
}
