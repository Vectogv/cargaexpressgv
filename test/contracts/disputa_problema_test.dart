import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/disputa_resultado.dart';

void main() {
  test('el motivo de la disputa nunca muestra el código crudo del backend', () {
    expect(etiquetaProblemaDisputa('cliente_rechaza_cierre'), 'Rechazaste la entrega');
    expect(etiquetaProblemaDisputa('cierre_sin_confirmar'), 'El cierre del viaje no se confirmó a tiempo');
    expect(etiquetaProblemaDisputa(null), '—');
    expect(etiquetaProblemaDisputa('Faltan 2 cajas'), 'Faltan 2 cajas');
  });

  test('la resolución explica qué pasa con el viaje', () {
    expect(consecuenciaParaCliente('favor_cliente'), contains('no se te cobra'));
    expect(consecuenciaParaCliente('favor_conductor'), contains('Pagos'));
    expect(consecuenciaParaCliente(null), '');
  });
}
