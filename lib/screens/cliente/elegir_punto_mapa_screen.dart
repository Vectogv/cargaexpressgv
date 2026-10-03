import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_permission.dart';
import '../shared/ui_compartida.dart';

/// Punto elegido en el mapa con su dirección legible.
class PuntoElegido {
  final LatLng punto;
  final String direccion;
  const PuntoElegido(this.punto, this.direccion);
}

/// Selector de punto a pantalla completa: el pin queda fijo en el centro y se
/// mueve el mapa por debajo. Devuelve un [PuntoElegido] (o null si se cancela).
class ElegirPuntoMapaScreen extends StatefulWidget {
  final bool esOrigen;
  final LatLng inicial;

  /// Origen ya elegido; solo se pinta cuando se elige el destino.
  final LatLng? origen;

  /// Dirección del centro, o null si no se pudo obtener.
  final Future<String?> Function(LatLng) direccionDe;

  /// Resultados de Nominatim (`display_name`, `lat`, `lon`) para un texto.
  final Future<List<Map<String, dynamic>>> Function(String) buscar;

  /// Mosaicos del mapa; null en pruebas (sin red).
  final TileLayer? capaMosaicos;

  const ElegirPuntoMapaScreen({
    super.key,
    required this.esOrigen,
    required this.inicial,
    required this.direccionDe,
    required this.buscar,
    this.origen,
    this.capaMosaicos,
  });

  @override
  State<ElegirPuntoMapaScreen> createState() => _ElegirPuntoMapaScreenState();
}

class _ElegirPuntoMapaScreenState extends State<ElegirPuntoMapaScreen> {
  static const Duration _espera = Duration(milliseconds: 600);

  final MapController _mapCtrl = MapController();
  final TextEditingController _busquedaCtrl = TextEditingController();
  late LatLng _centro = widget.inicial;
  Timer? _debounce;
  int _version = 0;
  String? _direccion;
  bool _cargando = true;
  bool _moviendo = false;
  bool _buscando = false;
  bool _ubicando = false;
  List<Map<String, dynamic>> _resultados = const [];
  String? _avisoBusqueda;

  Color get _color => widget.esOrigen ? ColoresApp.verde : ColoresApp.rojo;

  @override
  void initState() {
    super.initState();
    _programar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  /// Espera a que el mapa deje de moverse y busca la dirección; las
  /// respuestas de posiciones anteriores se descartan por [_version].
  void _programar() {
    _debounce?.cancel();
    final v = ++_version;
    _cargando = true;
    _debounce = Timer(_espera, () async {
      final p = _centro;
      String? dir;
      try {
        dir = await widget.direccionDe(p);
      } catch (_) {}
      if (!mounted || v != _version) return;
      setState(() {
        _direccion =
            dir ??
            'Ubicación seleccionada (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})';
        _cargando = false;
      });
    });
  }

  void _alMover(MapCamera camara, bool gesto) {
    setState(() {
      _centro = camara.center;
      if (gesto) _moviendo = true;
    });
    _programar();
  }

  void _alEvento(MapEvent e) {
    final fin =
        e is MapEventMoveEnd ||
        e is MapEventFlingAnimationEnd ||
        e is MapEventDoubleTapZoomEnd;
    if (fin && _moviendo) setState(() => _moviendo = false);
  }

  Future<void> _buscar() async {
    final q = _busquedaCtrl.text.trim();
    if (q.isEmpty || _buscando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _buscando = true;
      _avisoBusqueda = null;
    });
    List<Map<String, dynamic>> r = const [];
    try {
      r = await widget.buscar(q);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _buscando = false;
      _resultados = r;
      _avisoBusqueda = r.isEmpty
          ? 'No encontramos ese lugar. Prueba con otro o mueve el mapa.'
          : null;
    });
  }

  void _irA(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) return;
    setState(() {
      _resultados = const [];
      _avisoBusqueda = null;
      _busquedaCtrl.text = (item['display_name'] as String? ?? '')
          .split(',')
          .first;
    });
    _mapCtrl.move(LatLng(lat, lon), 17);
  }

  Future<void> _miUbicacion() async {
    if (_ubicando) return;
    setState(() => _ubicando = true);
    try {
      await LocationPermissionHelper.ensure(openSettings: false);
      final pos = await LocationPermissionHelper.currentPosition();
      if (mounted) _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 17);
    } on LocationException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso(LocationPermissionHelper.msgUnavailable);
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  void _aviso(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.esOrigen
        ? '¿Dónde recogemos?'
        : '¿A dónde lo llevamos?';
    final origen = widget.origen;
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      body: LayoutBuilder(
        builder: (context, c) {
          // Horizontal / pantallas anchas: la hoja pasa a panel lateral.
          final lateral = c.maxWidth > c.maxHeight && c.maxWidth >= 600;
          final anchoHoja = lateral ? 360.0 : 480.0;
          return Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: widget.inicial,
                    initialZoom: 16,
                    onPositionChanged: _alMover,
                    onMapEvent: _alEvento,
                  ),
                  children: [
                    if (widget.capaMosaicos != null) widget.capaMosaicos!,
                    if (!widget.esOrigen && origen != null) ...[
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [origen, _centro],
                            color: ColoresApp.azul,
                            strokeWidth: 3,
                            pattern: StrokePattern.dashed(
                              segments: const [8, 8],
                            ),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: origen,
                            child: const Icon(
                              Icons.trip_origin,
                              color: ColoresApp.verde,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Pin fijo: la punta queda exactamente en el centro del mapa.
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, -(_moviendo ? 32.0 : 22.0)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          key: const Key('pin_centro'),
                          color: _color,
                          size: 44,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  child: Align(
                    alignment: lateral
                        ? Alignment.topLeft
                        : Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: lateral ? 420 : 480,
                        maxHeight: c.maxHeight * 0.6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _tarjetaSuperior(titulo),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Align(
                    alignment: lateral
                        ? Alignment.bottomRight
                        : Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: anchoHoja,
                        maxHeight: c.maxHeight * 0.7,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(
                                  side: BorderSide(color: ColoresApp.borde),
                                ),
                                child: IconButton(
                                  key: const Key('mi_ubicacion'),
                                  tooltip: 'Mi ubicación',
                                  onPressed: _miUbicacion,
                                  icon: _ubicando
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location,
                                          color: ColoresApp.azul,
                                        ),
                                ),
                              ),
                            ),
                            Flexible(
                              child: SingleChildScrollView(child: _hoja()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tarjetaSuperior(String titulo) {
    final tema = Theme.of(context).textTheme;
    return TarjetaBlanca(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: ColoresApp.textoOscuro,
                ),
              ),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoOscuro,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextField(
              controller: _busquedaCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                hintText: 'Buscar calle, barrio o lugar',
                isDense: true,
                filled: true,
                fillColor: ColoresApp.fondo,
                prefixIcon: const Icon(Icons.search, color: ColoresApp.chevron),
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_avisoBusqueda != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
              child: Text(
                _avisoBusqueda!,
                style: tema.bodySmall?.copyWith(
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ),
          if (_resultados.isNotEmpty)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(left: 8, top: 4),
                children: [
                  for (final r in _resultados)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.place_outlined, color: _color),
                      title: Text(
                        r['display_name'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _irA(r),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hoja() {
    final tema = Theme.of(context).textTheme;
    final partes = (_direccion ?? '').split(',');
    final calle = partes.first.trim();
    final resto = partes.length > 1 ? partes.skip(1).join(',').trim() : '';
    final ocupado = _cargando || _moviendo;
    return TarjetaBlanca(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.esOrigen ? 'ORIGEN · RECOGIDA' : 'DESTINO · ENTREGA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ocupado) ...[
            _barra(key: const Key('cargando_direccion'), ancho: 0.8, alto: 16),
            const SizedBox(height: 8),
            _barra(ancho: 0.55, alto: 12),
          ] else ...[
            Text(
              calle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: ColoresApp.textoOscuro,
              ),
            ),
            if (resto.isNotEmpty)
              Text(
                resto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.bodyMedium?.copyWith(
                  color: ColoresApp.textoSecundario,
                ),
              ),
          ],
          const SizedBox(height: 14),
          BotonPrincipal(
            texto: widget.esOrigen ? 'Confirmar origen' : 'Confirmar destino',
            color: _color,
            onPressed: ocupado
                ? null
                : () => Navigator.pop(
                    context,
                    PuntoElegido(_centro, _direccion ?? ''),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _barra({Key? key, required double ancho, required double alto}) =>
      FractionallySizedBox(
        key: key,
        widthFactor: math.min(1, ancho),
        alignment: Alignment.centerLeft,
        child: Container(
          height: alto,
          decoration: BoxDecoration(
            color: ColoresApp.divisor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
}
