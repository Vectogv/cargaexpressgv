/// Formato único de la hora en la app: 12 horas, como la lee el usuario
/// ("2:44 p. m."). Recibe la hora ya en local.
library;

/// `14:05` → `2:05 p. m.`; `00:30` → `12:30 a. m.`
String hora12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}
