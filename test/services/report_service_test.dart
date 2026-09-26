import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cargaexpress/services/api/http_client.dart' show ApiException;
import 'package:cargaexpress/services/report_service.dart';

import '../helpers/fake_api.dart';

/// Memoria local de "ya reporté al conductor de este viaje": el detalle del
/// backend no lo informa y el botón reaparecía al volver a entrar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('yaReportado / marcarReportado guardan el id como texto (acepta número o texto)', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ReportService.yaReportado(35), isFalse);
    await ReportService.marcarReportado(35);
    expect(await ReportService.yaReportado('35'), isTrue);
    expect(await ReportService.yaReportado(35), isTrue);
    expect(await ReportService.yaReportado(36), isFalse);
    expect(await ReportService.yaReportado(null), isFalse);

    // No se duplica.
    await ReportService.marcarReportado('35');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(ReportService.prefViajesReportados), ['35']);
  });

  test('createReport marca el viaje al crear el reporte', () async {
    final log = <http.Request>[];
    await conApiFalsa(
      (_) => jsonResp({'id': '9', 'estado': 'pendiente', 'motivo': 'otro', 'reportadoPor': 'cliente'}, 201),
      () async {
        expect(await ReportService.yaReportado('34'), isFalse);
        await ReportService.createReport(tripId: '34', motivo: 'otro');
        expect(await ReportService.yaReportado('34'), isTrue);
      },
      log: log,
    );
    expect(log.single.url.path, '/api/trips/34/report');
  });

  test('createReport con 409 (ya reportado) relanza el error pero deja el viaje marcado', () async {
    await conApiFalsa(
      (_) => errorResp(409, 'Ya reportaste al conductor de este viaje'),
      () async {
        await expectLater(
          ReportService.createReport(tripId: '34', motivo: 'otro'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
        );
        expect(await ReportService.yaReportado('34'), isTrue);
      },
    );
  });

  test('createReport con otro error (422) no marca el viaje', () async {
    await conApiFalsa(
      (_) => errorResp(422, 'El viaje no tuvo conductor asignado'),
      () async {
        await expectLater(
          ReportService.createReport(tripId: '34', motivo: 'otro'),
          throwsA(isA<ApiException>()),
        );
        expect(await ReportService.yaReportado('34'), isFalse);
      },
    );
  });
}
