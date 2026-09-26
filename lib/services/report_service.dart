import 'package:shared_preferences/shared_preferences.dart';

import 'api/http_client.dart';
import '../models/report_model.dart';

class ReportService {
  /// Clave de SharedPreferences con los viajes cuyo conductor ya reportó
  /// este usuario. El detalle del viaje (GET /api/trips/:id) no informa si
  /// hay un reporte, así que se recuerda en el teléfono para no volver a
  /// ofrecer "Reportar conductor" (el backend respondería 409).
  static const String prefViajesReportados = 'viajes_reportados_cliente';

  /// Contrato backend: POST /api/trips/:id/report con `motivo` (enum) y
  /// `descripcion` opcional. El rol decide a quién se reporta:
  /// - conductor → cliente del viaje: no_pago, comportamiento, otro.
  /// - cliente → conductor asignado: no_se_presento, cobro_incorrecto,
  ///   comportamiento, otro. Repetido en el mismo viaje: 409.
  ///
  /// Si se crea (o el backend responde 409 porque ya existía) el viaje queda
  /// marcado como reportado en el teléfono; ver [yaReportado].
  static Future<ReportModel> createReport({
    required String tripId,
    required String motivo,
    String? descripcion,
  }) async {
    final payload = {
      'motivo': motivo,
      if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
    };
    try {
      final data = await HttpClient.post('/api/trips/$tripId/report', body: payload, auth: true);
      await marcarReportado(tripId);
      return ReportModel.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 409) await marcarReportado(tripId);
      rethrow;
    }
  }

  /// `true` si este usuario ya reportó al conductor de [tripId] desde este
  /// teléfono (acepta el id como texto o número).
  static Future<bool> yaReportado(dynamic tripId) async {
    if (tripId == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(prefViajesReportados) ?? const <String>[]).contains(tripId.toString());
    } catch (_) {
      return false;
    }
  }

  static Future<void> marcarReportado(dynamic tripId) async {
    if (tripId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = List<String>.from(prefs.getStringList(prefViajesReportados) ?? const <String>[]);
      final id = tripId.toString();
      if (lista.contains(id)) return;
      lista.add(id);
      // Se guardan los últimos 200: es solo una memoria de conveniencia.
      if (lista.length > 200) lista.removeRange(0, lista.length - 200);
      await prefs.setStringList(prefViajesReportados, lista);
    } catch (_) {
      // Sin persistencia local la app sigue funcionando (el backend da 409).
    }
  }

  static Future<List<ReportModel>> getReports() async {
    // Los reportes son visibles para admin en /api/admin/reports.
    final list = await HttpClient.getList('/api/admin/reports', auth: true);
    return list.cast<Map<String, dynamic>>().map((e) => ReportModel.fromJson(e)).toList();
  }
}
