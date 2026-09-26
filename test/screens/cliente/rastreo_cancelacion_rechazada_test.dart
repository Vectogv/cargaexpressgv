import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/contracts/socket_events.dart';
import 'package:cargaexpress/screens/cliente/rastreo_screen.dart';
import 'package:cargaexpress/services/socket_service_client.dart';

import '../../helpers/fake_api.dart';

/// El admin rechaza una solicitud de cancelación (`request-cancellation`,
/// en_curso/conductor_llegada/sos): el backend emite
/// `trip:cancellation_rejected` a cliente y conductor; el viaje sigue activo
/// y no debe sacarse a nadie de la pantalla (a diferencia de `trip:cancelled`).
void main() {
  Map<String, dynamic> viajeEnCurso() => {
        '_id': 't1',
        'estado': 'en_curso',
        'origen': {'lat': 4.6, 'lng': -74.1, 'direccion': 'Origen'},
        'destino': {'lat': 4.7, 'lng': -74.0, 'direccion': 'Destino'},
        'conductor': {'nombre': 'Carlos'},
      };

  testWidgets('muestra el aviso claro y no saca al cliente del viaje', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return jsonResp(viajeEnCurso());
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);

      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.tripCancellationRejected, {
        'id': '9',
        'viajeId': 't1',
        'estado': 'rechazado',
        'motivo': 'El viaje ya casi termina',
      });
      await avanzar(tester);

      expect(
        find.text('El administrador rechazó la cancelación. El viaje continúa. Motivo: El viaje ya casi termina.'),
        findsOneWidget,
      );
      // Sigue en el rastreo del viaje, no se lo devolvió al inicio.
      expect(find.byType(RastreoScreen), findsOneWidget);
    });
  });

  testWidgets('un evento de otro viaje (viajeId distinto) se ignora', (tester) async {
    pantallaAlta(tester);
    await conApiFalsa((req) {
      if (req.url.path == '/api/trips/active') return jsonResp(viajeEnCurso());
      return jsonResp({});
    }, () async {
      await tester.pumpWidget(const MaterialApp(home: RastreoScreen()));
      await avanzar(tester);

      SocketServiceClient.instance.simularEventoParaTest(SocketEvents.tripCancellationRejected, {
        'id': '9',
        'viajeId': 'otro-viaje',
        'estado': 'rechazado',
        'motivo': 'No debería verse',
      });
      await avanzar(tester);

      expect(find.textContaining('rechazó la cancelación'), findsNothing);
    });
  });
}
