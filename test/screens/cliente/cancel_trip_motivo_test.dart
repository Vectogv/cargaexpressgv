import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/cancel_trip_screen.dart';

void main() {
  test('el motivo elegido y el comentario se envían juntos', () {
    expect(componerMotivoCancelacion('Cambié de opinión'), 'Cambié de opinión');
    expect(componerMotivoCancelacion('Otro motivo', '  '), 'Otro motivo');
    expect(componerMotivoCancelacion('Otro motivo', 'Ya no lo necesito'), 'Otro motivo: Ya no lo necesito');
  });

  test('resultado de CancelTripScreen -> motivo (null si no eligió)', () {
    expect(motivoDesdeResultado(null), isNull);
    expect(motivoDesdeResultado({'reason': '', 'comment': 'x'}), isNull);
    expect(motivoDesdeResultado({'reason': 'Demora excesiva', 'comment': ''}), 'Demora excesiva');
    expect(motivoDesdeResultado({'reason': 'Problema con la carga', 'comment': 'Se mojó'}),
        'Problema con la carga: Se mojó');
  });
}
