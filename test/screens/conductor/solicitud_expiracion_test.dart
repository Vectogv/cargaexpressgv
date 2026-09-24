import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/conductor/conductor_trip_detail_screen.dart';

void main() {
  final ahora = DateTime.utc(2026, 9, 24, 18, 10);

  test('la solicitud sigue abierta los 15 min de búsqueda del backend, no 28 s', () {
    final creado = ahora.subtract(const Duration(seconds: 40)).toIso8601String();
    expect(segundosRestantesSolicitud({'createdAt': creado}, ahora), 15 * 60 - 40);
    expect(segundosRestantesSolicitud({'created_at': creado}, ahora), 15 * 60 - 40);
  });

  test('expiresIn del backend manda; vencida queda en 0; sin fecha, 15 min', () {
    expect(segundosRestantesSolicitud({'expiresIn': 90}, ahora), 90);
    final viejo = ahora.subtract(const Duration(minutes: 20)).toIso8601String();
    expect(segundosRestantesSolicitud({'createdAt': viejo}, ahora), 0);
    expect(segundosRestantesSolicitud({}, ahora), 15 * 60);
  });

  test('distancia en línea recta cuando el backend no la manda', () {
    final o = {'lat': 2.44188, 'lng': -76.60631};
    final d = {'lat': 2.46129, 'lng': -76.5915};
    expect(distanciaRectaTexto(o, d), '≈ 2.7 km en línea recta');
    expect(distanciaRectaTexto(o, null), '--');
  });
}
