import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show formatHttpDate;

import 'package:cargaexpress/services/api/http_client.dart';
import 'package:cargaexpress/services/server_clock.dart';

import '../helpers/fake_api.dart';

void main() {
  final local = DateTime.utc(2026, 9, 23, 15, 0, 0);

  setUp(() => ServerClock.ahoraLocal = () => local);
  tearDown(ServerClock.reiniciar);

  test('un desfase pequeño (precisión de segundos de Date) se ignora', () {
    ServerClock.registrarFecha(formatHttpDate(local.subtract(const Duration(seconds: 1))));
    expect(ServerClock.desfase, Duration.zero);
    expect(ServerClock.ahora(), local);
  });

  test('un reloj del teléfono atrasado se corrige con la hora del servidor', () {
    ServerClock.registrarFecha(formatHttpDate(local.add(const Duration(seconds: 40))));
    expect(ServerClock.desfase, const Duration(seconds: 40));
    expect(ServerClock.ahora(), local.add(const Duration(seconds: 40)));
  });

  test('cabecera ausente o mal formada conserva el desfase conocido', () {
    ServerClock.registrarFecha(formatHttpDate(local.subtract(const Duration(seconds: 30))));
    ServerClock.registrarFecha(null);
    ServerClock.registrarFecha('no es una fecha');
    expect(ServerClock.desfase, const Duration(seconds: -30));
  });

  test('HttpClient registra la cabecera Date de cada respuesta', () async {
    await conApiFalsa(
      (_) => http.Response('{}', 200, headers: {
        'content-type': 'application/json',
        'date': formatHttpDate(local.add(const Duration(minutes: 2))),
      }),
      () async {
        await HttpClient.get('/api/ping');
      },
    );
    expect(ServerClock.desfase, const Duration(minutes: 2));
  });
}
