import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http_parser/http_parser.dart' show parseHttpDate;

/// Hora del servidor estimada a partir de la cabecera `Date` de las
/// respuestas HTTP. Sirve para las cuentas regresivas que dependen de fechas
/// del backend (p. ej. `expiresAt` de las ofertas) aunque el reloj del
/// teléfono esté algo desfasado.
class ServerClock {
  ServerClock._();

  /// Desfases menores se ignoran: la cabecera `Date` sólo tiene precisión de
  /// segundos y la latencia de red añade otro poco.
  static const Duration tolerancia = Duration(seconds: 2);

  static Duration _desfase = Duration.zero;

  /// Reloj local (inyectable en pruebas).
  @visibleForTesting
  static DateTime Function() ahoraLocal = DateTime.now;

  /// Diferencia servidor - teléfono (cero si es pequeña o desconocida).
  static Duration get desfase => _desfase;

  /// Hora actual según el servidor.
  static DateTime ahora() => ahoraLocal().add(_desfase);

  /// Registra la cabecera `Date` de una respuesta recibida ahora.
  static void registrarFecha(String? httpDate) {
    if (httpDate == null || httpDate.isEmpty) return;
    try {
      final servidor = parseHttpDate(httpDate);
      final diferencia = servidor.difference(ahoraLocal());
      _desfase = diferencia.abs() <= tolerancia ? Duration.zero : diferencia;
    } catch (_) {
      // Cabecera mal formada: se conserva el último desfase conocido.
    }
  }

  @visibleForTesting
  static void reiniciar() {
    _desfase = Duration.zero;
    ahoraLocal = DateTime.now;
  }
}
