import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/widgets/solicitud_viaje_sheet.dart';

void main() {
  test('el aviso de nueva solicitud se cierra cuando el viaje ya no busca conductor', () {
    expect(solicitudSigueAbierta('buscando_conductor'), isTrue);
    expect(solicitudSigueAbierta('pendiente'), isTrue);
    expect(solicitudSigueAbierta(null), isTrue); // sin dato aún: no cerrar
    expect(solicitudSigueAbierta('aceptado'), isFalse);
    expect(solicitudSigueAbierta('cancelado'), isFalse);
  });
}
