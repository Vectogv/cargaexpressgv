import 'package:flutter/foundation.dart';

import 'api/http_client.dart';

/// Reglas que aplica el backend al cliente (GET /api/config/cliente).
class ReglasCliente {
  /// Distancia (km) bajo la cual el backend bloquea cancelar / exige cierre.
  final double radioCierreKm;

  /// Minutos sin confirmar la entrega antes de que un moderador revise.
  final int confirmacionTimeoutMin;

  /// Distancia (km) para avisar "el conductor está cerca", si el backend la
  /// envía; si no, se usa [radioCierreKm].
  final double? radioConductorCercaKm;

  const ReglasCliente({
    required this.radioCierreKm,
    required this.confirmacionTimeoutMin,
    this.radioConductorCercaKm,
  });

  /// Valores del backend en producción mientras el endpoint no exista.
  static const porDefecto = ReglasCliente(radioCierreKm: 1, confirmacionTimeoutMin: 10);

  double get radioAvisoConductorCercaKm => radioConductorCercaKm ?? radioCierreKm;

  /// Cada campo inválido o ausente cae en su valor por defecto.
  factory ReglasCliente.fromJson(Map<String, dynamic> json) {
    double? positivo(dynamic v) {
      final n = v is num ? v : num.tryParse(v?.toString() ?? '');
      return (n != null && n.isFinite && n > 0) ? n.toDouble() : null;
    }

    final timeout = positivo(json['confirmacionTimeoutMin']);
    return ReglasCliente(
      radioCierreKm: positivo(json['radioCierreKm']) ?? porDefecto.radioCierreKm,
      confirmacionTimeoutMin: timeout?.round() ?? porDefecto.confirmacionTimeoutMin,
      radioConductorCercaKm: positivo(json['radioConductorCercaKm']),
    );
  }
}

/// Obtiene y guarda en memoria las reglas del cliente. Si el endpoint falla
/// o aún no existe (producción), se usan [ReglasCliente.porDefecto] sin avisar.
class ConfigClienteService {
  ConfigClienteService._();
  static final ConfigClienteService instance = ConfigClienteService._();

  /// Tiempo antes de volver a consultar (con éxito o tras un fallo).
  static const Duration vigencia = Duration(minutes: 10);

  final ValueNotifier<ReglasCliente> reglas = ValueNotifier(ReglasCliente.porDefecto);
  DateTime? _consultado;
  Future<ReglasCliente>? _enCurso;

  ReglasCliente get actual => reglas.value;

  Future<ReglasCliente> cargar({bool forzar = false}) {
    final ultimo = _consultado;
    if (!forzar && ultimo != null && DateTime.now().difference(ultimo) < vigencia) {
      return Future.value(actual);
    }
    return _enCurso ??= _consultar().whenComplete(() => _enCurso = null);
  }

  Future<ReglasCliente> _consultar() async {
    try {
      final data = await HttpClient.get('/api/config/cliente', auth: true);
      reglas.value = ReglasCliente.fromJson(data);
    } catch (_) {
      // Sin endpoint o sin red: se conservan las últimas reglas conocidas.
    }
    _consultado = DateTime.now();
    return actual;
  }

  @visibleForTesting
  void reiniciarParaTest() {
    reglas.value = ReglasCliente.porDefecto;
    _consultado = null;
    _enCurso = null;
  }
}
