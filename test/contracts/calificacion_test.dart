import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/calificacion.dart';

void main() {
  test('sin calificaciones se muestra "Nuevo", nunca "0.0"', () {
    expect(etiquetaCalificacion(null), 'Nuevo');
    expect(etiquetaCalificacion(0), 'Nuevo');
    expect(etiquetaCalificacion('0.0'), 'Nuevo');
    expect(etiquetaCalificacion('abc'), 'Nuevo');
    expect(etiquetaCalificacion(4.8, totalViajes: 0), 'Nuevo');
  });

  test('con calificación se muestra con un decimal (número o texto decimal)', () {
    expect(etiquetaCalificacion(4.5), '4.5');
    expect(etiquetaCalificacion('4.50'), '4.5');
    expect(etiquetaCalificacion(5, totalViajes: 3), '5.0');
  });

  test('lee rating o calificacion del conductor', () {
    expect(etiquetaCalificacionConductor(null), 'Nuevo');
    expect(etiquetaCalificacionConductor({'rating': 4.2}), '4.2');
    expect(etiquetaCalificacionConductor({'calificacion': '3.9'}), '3.9');
    expect(etiquetaCalificacionConductor({'calificacion': 4, 'totalViajes': 0}), 'Nuevo');
  });
}
