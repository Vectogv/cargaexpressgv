import 'api/http_client.dart';
import '../models/report_model.dart';

class ReportService {
  /// Contrato backend: POST /api/trips/:id/report con `motivo` (enum) y
  /// `descripcion`. El motivo debe ser uno de: no_pago, comportamiento, otro.
  static Future<ReportModel> createReport({
    required String tripId,
    required String motivo,
    String? descripcion,
  }) async {
    final payload = {
      'motivo': motivo,
      if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
    };
    final data = await HttpClient.post('/api/trips/$tripId/report', body: payload, auth: true);
    return ReportModel.fromJson(data);
  }

  static Future<List<ReportModel>> getReports() async {
    // Los reportes son visibles para admin en /api/admin/reports.
    final list = await HttpClient.getList('/api/admin/reports', auth: true);
    return list.cast<Map<String, dynamic>>().map((e) => ReportModel.fromJson(e)).toList();
  }
}