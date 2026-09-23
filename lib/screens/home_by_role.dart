import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'admin/dashboard_screen.dart';
import 'cliente/home_screen.dart';
import 'conductor/home_screen.dart' as conductor;
import 'moderador/moderador_home_screen.dart';
import 'user/auth_screen.dart';

/// Destino de inicio de cada rol. Única fuente de verdad: la usan el login,
/// el registro y la recuperación de sesión en `main.dart`, para que un mismo
/// usuario vea siempre la misma pantalla de inicio.
enum HomeDestino { admin, moderador, conductor, cliente, ninguno }

/// El moderador en el backend es la bandera `esModerador` sobre un usuario
/// cliente/conductor (no un valor de `rol`); se acepta también
/// `rol == 'moderador'` por compatibilidad. Un admin siempre va al panel de
/// administración aunque tenga la bandera.
HomeDestino homeDestinoFor({String? rol, bool esModerador = false}) {
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
      return const AuthScreen();
  }
}

/// Destino de la sesión guardada en [ApiClient].
HomeDestino homeDestinoForSession() => homeDestinoFor(
      rol: ApiClient.instance.rol,
      esModerador: ApiClient.instance.esModerador,
    );

/// Abre [home] como única ruta de la pila. Se usa tras login y registro:
/// antes quedaba debajo la pantalla de autenticación, y cualquier
/// `popUntil((r) => r.isFirst)` (cancelar viaje, volver al inicio...)
/// llevaba a ella, como si se hubiera cerrado la sesión.
Future<void> abrirInicioComoRaiz(BuildContext context, Widget home) {
  return Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => home),
    (_) => false,
  );
}
