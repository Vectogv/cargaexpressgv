import 'api/http_client.dart';
import '../models/report_model.dart';

class ReportService {
  static Future<ReportModel> createReport({
    required String tipo,
    required String descripcion,
    String? tripId,
    String? targetId,
  }) async {
    final payload = {
      'tipo': tipo,
      'descripcion': descripcion,
      'tripId': tripId,
      'targetId': targetId,
    };
    final data = await HttpClient.post('/api/reports', body: payload, auth: true);
    return ReportModel.fromJson(data);
  }

  static Future<List<ReportModel>> getReports() async {
    final list = await HttpClient.getList('/api/reports', auth: true);
    return list.cast<Map<String, dynamic>>().map((e) => ReportModel.fromJson(e)).toList();
  }
}
