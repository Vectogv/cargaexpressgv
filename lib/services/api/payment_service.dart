import '../api/http_client.dart';

/// Misma regla que POST /api/payment/proof (payment_controller.uploadProof):
/// se paga cuando se quiera mientras haya deuda, sin esperar la suspensión;
/// sólo se bloquea si no hay deuda o ya hay un comprobante en revisión.
bool puedeSubirComprobante(Map<String, dynamic>? deuda) {
  if (deuda == null || deuda['estadoCuenta'] == 'esperando_confirmacion') return false;
  final raw = deuda['montoDeuda'];
  final monto = raw is num ? raw : num.tryParse(raw?.toString() ?? '') ?? 0;
  return monto > 0;
}

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