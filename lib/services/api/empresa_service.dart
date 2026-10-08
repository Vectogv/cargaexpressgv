import 'dart:typed_data';

import 'http_client.dart';

/// Cuentas de empresa (fase 1). Acepta las respuestas con o sin envoltura `data`.
class EmpresaService {
  static Map<String, dynamic> _sinEnvoltura(Map<String, dynamic> d) =>
      d['data'] is Map ? Map<String, dynamic>.from(d['data'] as Map) : d;

  /// Registra la empresa (o reenvía una rechazada) con RUT y Cámara de Comercio.
  static Future<Map<String, dynamic>> registrar({
    required String nombre,
    required String nit,
    required String direccion,
    required String telefono,
    required Uint8List rut,
    required String rutNombre,
    required Uint8List camara,
    required String camaraNombre,
  }) async {
    final d = await HttpClient.uploadFile(
      '/api/empresas',
      bytes: rut,
      filename: rutNombre,
      fieldName: 'rut',
      auth: true,
      fields: {'nombre': nombre, 'nit': nit, 'direccion': direccion, 'telefono': telefono},
      extraFiles: [(fieldName: 'camara', bytes: camara, filename: camaraNombre)],
    );
    return _sinEnvoltura(d);
  }

  /// `{empresa: null}` o `{empresa, miembros, resumen}`.
  static Future<Map<String, dynamic>> mia() async => _sinEnvoltura(await HttpClient.get('/api/empresas/mia', auth: true));

  /// PDF del reporte del mes (`YYYY-MM`).
  static Future<List<int>> reporte(String mes) => HttpClient.getBytes('/api/empresas/reporte?mes=$mes', auth: true);

  static Future<void> unirse(String codigo) async {
    await HttpClient.post('/api/empresas/unirse', body: {'codigo': codigo}, auth: true);
  }

  static Future<void> salir() async {
    await HttpClient.post('/api/empresas/salir', auth: true);
  }

  static Future<void> quitarMiembro(Object userId) async {
    await HttpClient.delete('/api/empresas/miembros/$userId', auth: true);
  }
}
