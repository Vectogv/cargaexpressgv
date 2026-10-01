import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/services/notification_service.dart';

void main() {
  test('ticketIdDe: usa ticketId, y si falta lo saca de "ticket #N" en el título', () {
    expect(NotificationService.ticketIdDe({'ticketId': '7'}), '7');
    expect(NotificationService.ticketIdDe({'data': {'ticketId': 9}}), '9');
    expect(NotificationService.ticketIdDe({'tipo': 'ticket_mensaje', 'titulo': 'Respuesta en ticket #42'}), '42');
    expect(NotificationService.ticketIdDe({'type': 'ticket_estado', 'title': 'Ticket #5 resuelto'}), '5');
    // Otros tipos no se interpretan.
    expect(NotificationService.ticketIdDe({'tipo': 'viaje_estado', 'titulo': 'Viaje #3'}), isNull);
  });
}
