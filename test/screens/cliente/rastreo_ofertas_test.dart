import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';

void main() {
  test('las ofertas cargadas por GET se suman a las del socket sin duplicar', () {
    final actuales = [
      {'_id': 'o1', 'monto': 100},
    ];
    final servidor = [
      {'_id': 'o1', 'monto': 100},
      {'id': 'o2', 'monto': 120},
    ];

    final r = fusionarOfertas(actuales, servidor);

    expect(r.map((o) => o['_id'] ?? o['id']), ['o1', 'o2']);
  });

  test('ofertas sin id se agregan tal cual; listas vacías no fallan', () {
    expect(fusionarOfertas([], []), isEmpty);
    expect(fusionarOfertas([], [{'monto': 5}]).length, 1);
  });
}
