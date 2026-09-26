import 'package:flutter/widgets.dart';

/// Navegador raíz de la app (`MaterialApp.navigatorKey`). Lo usan los
/// servicios que necesitan abrir una pantalla sin un `BuildContext` a mano:
/// el toque de un push (abrir el detalle de un ticket) y los eventos de
/// sesión (volver a la bienvenida).
final GlobalKey<NavigatorState> navegadorGlobal = GlobalKey<NavigatorState>();
