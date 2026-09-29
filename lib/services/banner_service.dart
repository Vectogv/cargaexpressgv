import 'package:flutter/foundation.dart';

import 'api/http_client.dart';

/// Banner que la gerencia configura en el panel (Configuración → Banner,
/// GET/PUT /api/config/banner). Si no está activo o no tiene texto, no hay
/// nada que mostrar.
class BannerPlataforma {
  final bool activo;
  final String texto;
  final String? link;

  const BannerPlataforma({required this.activo, required this.texto, this.link});

  static const vacio = BannerPlataforma(activo: false, texto: '');

  bool get visible => activo && texto.isNotEmpty;

  factory BannerPlataforma.fromJson(Map<String, dynamic> json) {
    final texto = (json['texto'] ?? '').toString().trim();
    final link = (json['link'] ?? '').toString().trim();
    return BannerPlataforma(activo: json['activo'] == true, texto: texto, link: link.isEmpty ? null : link);
  }
}

/// Obtiene y guarda en memoria el banner de la plataforma. Si el endpoint
/// falla o aún no existe, se conserva el último banner conocido (o vacío)
/// sin avisar: el banner es informativo, no crítico.
class BannerService {
  BannerService._();
  static final BannerService instance = BannerService._();

  static const Duration vigencia = Duration(minutes: 10);

  final ValueNotifier<BannerPlataforma> banner = ValueNotifier(BannerPlataforma.vacio);
  DateTime? _consultado;
  Future<BannerPlataforma>? _enCurso;

  Future<BannerPlataforma> cargar({bool forzar = false}) {
    final ultimo = _consultado;
    if (!forzar && ultimo != null && DateTime.now().difference(ultimo) < vigencia) {
      return Future.value(banner.value);
    }
    return _enCurso ??= _consultar().whenComplete(() => _enCurso = null);
  }

  Future<BannerPlataforma> _consultar() async {
    try {
      final data = await HttpClient.get('/api/config/banner');
      banner.value = BannerPlataforma.fromJson(data);
    } catch (_) {
      // Sin red o el endpoint aún no existe: se conserva lo último conocido.
    }
    _consultado = DateTime.now();
    return banner.value;
  }

  @visibleForTesting
  void reiniciarParaTest() {
    banner.value = BannerPlataforma.vacio;
    _consultado = null;
    _enCurso = null;
  }
}
