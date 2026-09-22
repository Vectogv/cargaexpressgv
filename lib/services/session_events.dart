import 'dart:async';

/// Tipo de evento global de sesión.
enum SessionEventType { expired, suspended }

/// Evento de sesión: la sesión expiró (refresh inválido) o la cuenta fue
/// suspendida por el backend (`code == 'CUENTA_SUSPENDIDA'`).
class SessionEvent {
  final SessionEventType type;
  final String? message;

  const SessionEvent(this.type, [this.message]);

  @override
  String toString() => 'SessionEvent($type, $message)';
}

/// Bus global de eventos de sesión. `main.dart` lo escucha una sola vez y
/// lleva al usuario al login mostrando el mensaje; las pantallas no necesitan
/// manejar la suspensión/expiración por su cuenta.
class SessionEvents {
  static final SessionEvents instance = SessionEvents._();
  SessionEvents._();

  final StreamController<SessionEvent> _ctrl =
      StreamController<SessionEvent>.broadcast();

  Stream<SessionEvent> get stream => _ctrl.stream;

  void emit(SessionEvent e) {
    if (!_ctrl.isClosed) _ctrl.add(e);
  }
}
