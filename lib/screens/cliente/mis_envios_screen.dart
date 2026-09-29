import 'package:flutter/material.dart';
import '../../contracts/cancelacion.dart';
import '../../contracts/trip_status.dart';
import '../../services/api_client.dart';
import '../shared/ui_compartida.dart';
import 'viaje_detalle_screen.dart';
import '../../core/formato_dinero.dart';

const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

enum _Filtro { todos, curso, entregados, cancelados }

class MisEnviosScreen extends StatefulWidget {
  const MisEnviosScreen({super.key});

  @override
  State<MisEnviosScreen> createState() => _MisEnviosScreenState();
}

class _MisEnviosScreenState extends State<MisEnviosScreen> {
  List<Map<String, dynamic>> _viajes = [];
  bool _loading = true;
  String? _error;
  _Filtro _filtro = _Filtro.todos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.instance.getTripHistory();
      if (mounted) setState(() { _viajes = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _estadoLabel(String estado, {String? motivoCancelacion}) {
    switch (estado) {
      case 'buscando_conductor': return 'Buscando conductor';
      case 'aceptado': return 'Aceptado';
      case 'en_curso': return 'En curso';
      case 'esperando_confirmacion': return 'Esperando confirmación';
      case 'finalizado': return 'Entregado';
      case 'cancelado': return etiquetaCancelacion(motivoCancelacion);
      default: return TripStatus.label(estado);
    }
  }

  _Filtro _categoria(String estado) => switch (estado) {
        'finalizado' => _Filtro.entregados,
        'cancelado' => _Filtro.cancelados,
        _ => _Filtro.curso,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: ColoresApp.fondo,
        surfaceTintColor: ColoresApp.fondo,
        foregroundColor: ColoresApp.textoOscuro,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        automaticallyImplyLeading: Navigator.canPop(context),
        title: const Text('Mis envíos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: ColoresApp.chevron),
                        const SizedBox(height: 12),
                        const Text('Error al cargar envíos', style: TextStyle(color: ColoresApp.textoSecundario)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _viajes.isEmpty
                  ? const Center(child: Text('No tienes envíos', style: TextStyle(color: ColoresApp.textoSecundario)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [_buildFiltros(), const SizedBox(height: 16), ..._buildGrupos()],
                      ),
                    ),
    );
  }

  Widget _buildFiltros() {
    const etiquetas = {
      _Filtro.todos: 'Todos',
      _Filtro.curso: 'En curso',
      _Filtro.entregados: 'Entregados',
      _Filtro.cancelados: 'Cancelados',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in etiquetas.entries) ...[
            if (e.key != _Filtro.todos) const SizedBox(width: 8),
            _chip(e.key, e.value),
          ],
        ],
      ),
    );
  }

  Widget _chip(_Filtro f, String texto) {
    final activo = f == _filtro;
    return Semantics(
      selected: activo,
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _filtro = f),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? ColoresApp.textoOscuro : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: activo ? ColoresApp.textoOscuro : ColoresApp.bordeCampo),
          ),
          child: Text(texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                color: activo ? Colors.white : ColoresApp.textoOscuro,
              )),
        ),
      ),
    );
  }

  /// Agrupa por mes, en el orden en que llegan del servidor.
  List<Widget> _buildGrupos() {
    final visibles = _viajes
        .where((v) => _filtro == _Filtro.todos || _categoria(v['estado'] as String? ?? '') == _filtro)
        .toList();
    if (visibles.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: Text('No hay envíos en esta categoría', style: TextStyle(color: ColoresApp.textoSecundario))),
        ),
      ];
    }
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final v in visibles) {
      final fecha = DateTime.tryParse(v['createdAt'] as String? ?? '')?.toLocal();
      final clave = fecha == null ? 'Sin fecha' : '${_meses[fecha.month - 1][0].toUpperCase()}${_meses[fecha.month - 1].substring(1)} ${fecha.year}';
      grupos.putIfAbsent(clave, () => []).add(v);
    }
    return [
      for (final g in grupos.entries) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(g.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.textoSecundario)),
        ),
        TarjetaBlanca(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < g.value.length; i++) ...[
                if (i > 0) const Divider(height: 1, thickness: 1, color: ColoresApp.divisor),
                _buildFila(g.value[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  Widget _buildFila(Map<String, dynamic> v) {
    String corta(Map<String, dynamic>? p) => (p?['direccion'] as String? ?? '').split(',').first.trim();
    final origen = corta(v['origen'] as Map<String, dynamic>?);
    final destino = corta(v['destino'] as Map<String, dynamic>?);
    final estado = v['estado'] as String? ?? '';
    final fecha = DateTime.tryParse(v['createdAt'] as String? ?? '')?.toLocal();
    final (punto, texto) = switch (_categoria(estado)) {
      _Filtro.entregados => (ColoresApp.textoOscuro, ColoresApp.textoSecundario),
      _Filtro.cancelados => (ColoresApp.naranja, ColoresApp.naranjaTexto),
      _ => (ColoresApp.azul, ColoresApp.azul),
    };
    // precioFinal es el monto real; el estimado sólo si aún no hay final.
    num? precio(dynamic x) => x is num ? x : num.tryParse(x?.toString() ?? '');
    final monto = precio(v['precioFinal']) ?? precio(v['precioEstimado']);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViajeDetalleScreen(tripId: v['_id'] ?? v['id']))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text(fecha == null ? '–' : '${fecha.day}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
                  Text(fecha == null ? '' : _meses[fecha.month - 1].substring(0, 3),
                      style: const TextStyle(fontSize: 12, color: ColoresApp.textoSecundario)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$origen a $destino',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: punto, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(_estadoLabel(estado, motivoCancelacion: v['motivoCancelacion'] as String?),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: texto)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (monto != null) ...[
              const SizedBox(width: 8),
              Text(formatearPesos(monto),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColoresApp.textoOscuro, fontFeatures: cifrasTabulares)),
            ],
          ],
        ),
      ),
    );
  }
}
