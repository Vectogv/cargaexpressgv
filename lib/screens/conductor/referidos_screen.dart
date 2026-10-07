import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../widgets/error_carga.dart';
import '../shared/ui_compartida.dart';

/// Programa de referidos (GET /api/drivers/referidos): código propio para
/// invitar colegas, reglas, descuentos de comisión e invitados.
class ReferidosScreen extends StatefulWidget {
  const ReferidosScreen({super.key});

  @override
  State<ReferidosScreen> createState() => _ReferidosScreenState();
}

class _ReferidosScreenState extends State<ReferidosScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final d = await ApiClient.instance.getReferidos();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    }
  }

  static String _fecha(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static int _dias(Object? iso) {
    final d = DateTime.tryParse('$iso');
    return d == null ? 0 : d.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  List<Map<String, dynamic>> _lista(String k) => (_data?[k] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];

  String _conPct(Object? p) => p == 0 ? 'sin comisión' : 'con $p % de comisión';

  String get _codigo => '${_data?['codigo'] ?? ''}';

  Future<void> _compartir() {
    final texto = 'Regístrate como conductor en CargaExpress y usa mi código $_codigo para tener descuento en la comisión.';
    return launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}'), mode: LaunchMode.externalApplication);
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _codigo));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: ColoresApp.textoOscuro,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: ColoresApp.borde)),
        title: const Text('Invita a un colega', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _data == null
          ? (_error != null
              ? ErrorCarga(titulo: 'No pudimos cargar el programa', detalle: _error, onReintentar: _cargar)
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(padding: const EdgeInsets.all(16), children: _contenido()),
            ),
    );
  }

  List<Widget> _contenido() {
    if (_data!['programaActivo'] != true) {
      return const [CajaAviso(texto: 'El programa de referidos no está activo por ahora.')];
    }
    final r = (_data!['reglas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final inv = (r['invitado'] as Map?) ?? const {};
    final ref = (r['referidor'] as Map?) ?? const {};
    final prog = _data!['miProgreso'] as Map?;
    final cupones = _lista('cupones');
    final invitados = _lista('invitados');
    return [
      TarjetaBlanca(
        child: Column(children: [
          const Text('Tu código', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario)),
          const SizedBox(height: 6),
          Text(_codigo, key: const Key('referidos_codigo'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 3, color: ColoresApp.azul)),
          const SizedBox(height: 14),
          BotonPrincipal(texto: 'Compartir por WhatsApp', icono: Icons.share_outlined, onPressed: _compartir),
          const SizedBox(height: 8),
          BotonSecundario(texto: 'Copiar', icono: Icons.copy_outlined, onPressed: _copiar),
        ]),
      ),
      _titulo('Cómo funciona'),
      Text(
        'Quien se registre con tu código trabaja ${_conPct(inv['pct'])} en sus primeros ${inv['viajes']} viajes.\n'
        'Cuando haga ${r['viajesMeta']} viajes${r['clientesDistintos'] == true ? ' con clientes distintos' : ''} en ${r['diasMeta']} días, '
        'tú trabajas ${_conPct(ref['pct'])} en ${ref['viajes']} viajes (tienes ${ref['diasUso']} días para usarlos).',
        style: const TextStyle(fontSize: 13, height: 1.4, color: ColoresApp.textoSecundario),
      ),
      if (prog != null) ...[
        const SizedBox(height: 12),
        TarjetaBlanca(
          child: Text('Viaje ${prog['viajes']} de ${prog['meta']} · te quedan ${_dias(prog['venceEn'])} días',
              key: const Key('referidos_progreso'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
      _titulo('Mis descuentos'),
      if (cupones.isEmpty)
        const Text('Aún no tienes descuentos.', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario))
      else
        for (final c in cupones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TarjetaBlanca(
              child: Row(children: [
                Expanded(
                  child: Text('${c['pct'] == 0 ? 'Sin comisión' : '${c['pct']} % de comisión'} · quedan ${c['usosRestantes']} viajes', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Text('hasta ${_fecha(c['venceEn'])}', style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
              ]),
            ),
          ),
      _titulo('Tus invitados'),
      if (invitados.isEmpty)
        const Text('Todavía nadie se registró con tu código. ¡Invita a un colega!', style: TextStyle(fontSize: 13, color: ColoresApp.textoSecundario))
      else
        for (final i in invitados)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TarjetaBlanca(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i['nombre']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Viaje ${i['viajes']} de ${i['meta']}', style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
                  ]),
                ),
                switch (i['estado']) {
                  'activo' => const ChipEstado.verde('Cumplido'),
                  'vencido' => const ChipEstado.naranja('Vencido'),
                  'anulado' => const ChipEstado.rojo('Anulado'),
                  _ => const ChipEstado.azul('En curso'),
                },
              ]),
            ),
          ),
    ];
  }
}
