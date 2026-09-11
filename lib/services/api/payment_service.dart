import '../api/http_client.dart';

class PaymentService {
  static Future<Map<String, dynamic>> getDebt() async {
    return HttpClient.get('/api/payment/debt', auth: true);
  }

  static Future<Map<String, dynamic>> getDebtInfo() async {
    return HttpClient.get('/api/payments', auth: true);
  }

  static Future<Map<String, dynamic>> uploadProof({
    required List<int> bytes,
    required String filename,
  }) async {
    return HttpClient.uploadFile(
      '/api/payment/proof',
      bytes: bytes,
      filename: filename,
      fieldName: 'file',
      auth: true,
    );
  }
}