import '../api/http_client.dart';
import '../../models/payment_model.dart';

class PaymentService {
  static Future<Map<String, dynamic>> getDebt() async {
    return HttpClient.get('/api/payment/debt', auth: true);
  }

  static Future<List<PaymentModel>> getPayments() async {
    final list = await HttpClient.getList('/api/payments', auth: true);
    return list.cast<Map<String, dynamic>>().map((e) => PaymentModel.fromJson(e)).toList();
  }
}
