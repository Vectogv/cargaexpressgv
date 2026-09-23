import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/api/coverage_service.dart';
import '../../services/api/http_client.dart';
import '../../services/map_config.dart';
import '../../services/location_permission.dart';
import '../../services/logger_service.dart';
import '../shared/action_key.dart';
import 'rastreo_screen.dart';

const Color _kPrimary = Color(0xFF2563EB);
const Color _kOrigen = Color(0xFF16A34A);
const Color _kDestino = Color(0xFFDC2626);
const Color _kBorde = Color(0xFFE8E8E8);

class NuevoEnvioScreen extends StatefulWidget {
  /// Cliente HTTP para geocodificación (Nominatim). Inyectable en pruebas.
  final http.Client? geoClient;

  /// En pruebas se omite el mapa (descarga tiles de la red).
  final bool mostrarMapa;

  const NuevoEnvioScreen({super.key, this.geoClient, this.mostrarMapa = true});

  @override
  State<NuevoEnvioScreen> createState() => _NuevoEnvioScreenState();
}

class _NuevoEnvioScreenState extends State<NuevoEnvioScreen> {
  static const String _prefOrigen = 'nuevo_envio_origen';
  static const String _prefDestino = 'nuevo_envio_destino';
  static const String _prefOrigenLL = 'nuevo_envio_origen_ll';
  static const String _prefDestinoLL = 'nuevo_envio_destino_ll';
  static const String _prefDescripcion = 'nuevo_envio_descripcion';
  static const String _prefPrecio = 'nuevo_envio_precio';

  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _mapCtrl = MapController();

  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;
  LatLng _center = const LatLng(6.2476, -75.5658);
  bool _mapaListo = false;
  bool _loading = false;
  Timer? _draftTimer;
  final ActionKey _requestKey = ActionKey();

  // Estado de "usar mi ubicación".
  bool _loadingLocation = false;
  bool _locParaOrigen = true;
  LocationIssue? _locIssue;
  String? _locError;

  // Búsqueda / geocodificación en curso por punto.
  bool _resolviendoOrigen = false;
  bool _resolviendoDestino = false;

  // Cada selección de un punto incrementa su versión: un resultado tardío
  // (GPS o dirección) de una selección anterior ya no se aplica.
  int _versionOrigen = 0;
  int _versionDestino = 0;

  bool _precioTocado = false;

  // Nominatim (política de uso): User-Agent que identifica la app, máx. 1
  // petición/s y sin respuestas obsoletas.
  static const Map<String, String> _nominatimHeaders = {
    'User-Agent': 'CargaExpress/1.0 (com.cargaexpress.app)',
    'Accept-Language': 'es',
  };
  static const Duration _nominatimGap = Duration(milliseconds: 1000);
  late final http.Client _geoClient = widget.geoClient ?? http.Client();
  DateTime _lastGeoRequest = DateTime.fromMillisecondsSinceEpoch(0);

  // Opciones del mapa y capa de tiles creadas una sola vez.
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: _center,
    initialZoom: 13,
    onTap: _onMapTapped,
    onMapReady: () => _mapaListo = true,
  );
  late final TileLayer _tileLayer = TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app');

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Zonas de cobertura; null si no se pudieron cargar (no se avisa nada y
  /// el backend sigue validando al solicitar).
  List<Map<String, dynamic>>? _zonas;

  /// El backend sólo valida la cobertura del ORIGEN (trip_controller.request).
  bool get _origenFueraDeCobertura {
    final o = _origenLatLng;
    final zonas = _zonas;
    if (o == null || zonas == null) return false;
    return !isInsideCoverage(zonas, o.latitude, o.longitude);
  }

  Future<void> _cargarCobertura() async {
    try {
      final zonas = await CoverageService.getCoverage();
      if (mounted) setState(() => _zonas = zonas);
    } catch (e) {
      LoggerService.instance.warning('nuevo_envio: no se pudo cargar la cobertura', e);
    }
  }

  Future<void> _init() async {
    unawaited(_cargarCobertura());
    await _loadDraft();
    if (!mounted) return;
    _origenCtrl.addListener(_saveDraft);
    _destinoCtrl.addListener(_saveDraft);
    _descripcionCtrl.addListener(_saveDraft);
    _precioCtrl.addListener(_saveDraft);
    // Sin origen guardado: proponer la ubicación actual como punto de recogida.
    if (_origenLatLng == null) _getCurrentLocation(isOrigen: true);
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final origen = _parseLL(prefs.getString(_prefOrigenLL));
      final destino = _parseLL(prefs.getString(_prefDestinoLL));
      final origenTxt = prefs.getString(_prefOrigen) ?? '';
      final destinoTxt = prefs.getString(_prefDestino) ?? '';
      if (!mounted) return;
      setState(() {
        // Un punto sin coordenadas no sirve para solicitar: se descarta.
        if (origen != null && origenTxt.trim().isNotEmpty) {
          _origenLatLng = origen;
          _origenCtrl.text = origenTxt;
        }
        if (destino != null && destinoTxt.trim().isNotEmpty) {
          _destinoLatLng = destino;
          _destinoCtrl.text = destinoTxt;
        }
        _descripcionCtrl.text = prefs.getString(_prefDescripcion) ?? '';
        _precioCtrl.text = formatearMiles(prefs.getString(_prefPrecio) ?? '');
      });
    } catch (e) {
      LoggerService.instance.warning('nuevo_envio._loadDraft error', e);
    }
  }

  static LatLng? _parseLL(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static String _llToPref(LatLng? p) => p == null ? '' : '${p.latitude},${p.longitude}';

  void _saveDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), () {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_prefOrigen, _origenCtrl.text);
        prefs.setString(_prefDestino, _destinoCtrl.text);
        prefs.setString(_prefOrigenLL, _llToPref(_origenLatLng));
        prefs.setString(_prefDestinoLL, _llToPref(_destinoLatLng));
        prefs.setString(_prefDescripcion, _descripcionCtrl.text);
        prefs.setString(_prefPrecio, _precioCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _origenCtrl.removeListener(_saveDraft);
    _destinoCtrl.removeListener(_saveDraft);
    _descripcionCtrl.removeListener(_saveDraft);
    _precioCtrl.removeListener(_saveDraft);
    _draftTimer?.cancel();
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _mapCtrl.dispose();
    if (widget.geoClient == null) _geoClient.close();
    super.dispose();
  }

  // ── Puntos ────────────────────────────────────────────────────────────────

  static String _coords(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

  /// Fija un punto de inmediato (con [texto] provisional) y devuelve su versión.
  int _setPunto(bool isOrigen, LatLng p, String texto, {bool mover = true}) {
    setState(() {
      if (isOrigen) {
        _origenLatLng = p;
        _origenCtrl.text = texto;
        _versionOrigen++;
        // Elegir el origen a mano resuelve el aviso de ubicación.
        if (_locParaOrigen) {
          _locError = null;
          _locIssue = null;
        }
      } else {
        _destinoLatLng = p;
        _destinoCtrl.text = texto;
        _versionDestino++;
        if (!_locParaOrigen) {
          _locError = null;
          _locIssue = null;
        }
      }
    });
    if (mover) _encuadrar(p);
    return isOrigen ? _versionOrigen : _versionDestino;
  }

  void _encuadrar(LatLng ultimo) {
    _center = ultimo;
    if (!widget.mostrarMapa || !_mapaListo) return;
    try {
      final o = _origenLatLng;
      final d = _destinoLatLng;
      if (o != null && d != null && _distanciaKm(o, d) > 0.05) {
        _mapCtrl.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([o, d]),
          padding: const EdgeInsets.fromLTRB(40, 50, 60, 40),
        ));
      } else {
        _mapCtrl.move(ultimo, 15);
      }
    } catch (e) {
      LoggerService.instance.warning('nuevo_envio._encuadrar error', e);
    }
  }

  /// Busca la dirección del punto sin bloquear: si falla, el punto se queda
  /// con el texto provisional (coordenadas).
  Future<void> _resolverDireccion(bool isOrigen, LatLng p, int version) async {
    setState(() => isOrigen ? _resolviendoOrigen = true : _resolviendoDestino = true);
    final dir = await _reverseGeocode(p);
    if (!mounted) return;
    final vigente = version == (isOrigen ? _versionOrigen : _versionDestino);
    setState(() {
      if (isOrigen) {
        _resolviendoOrigen = false;
        if (vigente && dir != null) _origenCtrl.text = dir;
      } else {
        _resolviendoDestino = false;
        if (vigente && dir != null) _destinoCtrl.text = dir;
      }
    });
  }

  Future<void> _getCurrentLocation({bool isOrigen = true}) async {
    if (_loadingLocation) return;
    final version = isOrigen ? _versionOrigen : _versionDestino;
    setState(() {
      _loadingLocation = true;
      _locParaOrigen = isOrigen;
      _locError = null;
      _locIssue = null;
    });
    try {
      await LocationPermissionHelper.ensure(openSettings: false);
      final pos = await LocationPermissionHelper.currentPosition();
      if (!mounted) return;
      // El usuario eligió el punto a mano mientras esperaba: no sobrescribir.
      if (version != (isOrigen ? _versionOrigen : _versionDestino)) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      final v = _setPunto(isOrigen, latLng, 'Mi ubicación actual (${_coords(latLng)})');
      unawaited(_resolverDireccion(isOrigen, latLng, v));
    } on LocationException catch (e) {
      if (mounted) {
        setState(() {
          _locIssue = e.issue;
          _locError = e.message;
        });
      }
    } catch (e) {
      LoggerService.instance.warning('nuevo_envio._getCurrentLocation error', e);
      if (mounted) {
        setState(() {
          _locIssue = LocationIssue.unavailable;
          _locError = LocationPermissionHelper.msgUnavailable;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  /// GET a Nominatim respetando 1 petición/s y con timeout.
  Future<http.Response> _nominatimGet(Uri uri) async {
    final wait = _nominatimGap - DateTime.now().difference(_lastGeoRequest);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _lastGeoRequest = DateTime.now();
    return _geoClient.get(uri, headers: _nominatimHeaders).timeout(const Duration(seconds: 10));
  }

  /// Dirección legible del punto, o null si no se pudo obtener.
  Future<String?> _reverseGeocode(LatLng latLng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${latLng.latitude}&lon=${latLng.longitude}&format=json&accept-language=es',
      );
      final res = await _nominatimGet(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final name = data['display_name'] as String?;
        if (name != null && name.trim().isNotEmpty) return name;
      }
    } catch (e) {
      LoggerService.instance.warning('nuevo_envio._reverseGeocode error', e);
    }
    return null;
  }

  void _elegirEnMapa(LatLng latLng, {required bool isOrigen}) {
    final v = _setPunto(isOrigen, latLng, 'Ubicación seleccionada en el mapa (${_coords(latLng)})', mover: false);
    _encuadrar(latLng);
    unawaited(_resolverDireccion(isOrigen, latLng, v));
  }

  void _onMapTapped(TapPosition tap, LatLng latLng) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Marcar este punto como...'),
        children: [
          SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); _elegirEnMapa(latLng, isOrigen: true); },
            child: const ListTile(leading: Icon(Icons.trip_origin, color: _kOrigen), title: Text('Origen (recogida)'), dense: true, contentPadding: EdgeInsets.zero),
          ),
          SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); _elegirEnMapa(latLng, isOrigen: false); },
            child: const ListTile(leading: Icon(Icons.location_on, color: _kDestino), title: Text('Destino (entrega)'), dense: true, contentPadding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  /// Opciones para elegir un punto (al tocar la fila de origen o destino).
  Future<void> _elegirPunto({required bool isOrigen}) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  isOrigen ? '¿Dónde recogemos?' : '¿A dónde lo llevamos?',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search, color: _kPrimary),
                title: const Text('Buscar dirección'),
                subtitle: const Text('Escribe calle, barrio o lugar'),
                onTap: () => Navigator.pop(ctx, 'search'),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: _kPrimary),
                title: const Text('Elegir en el mapa'),
                subtitle: const Text('Toca el punto exacto'),
                onTap: () => Navigator.pop(ctx, 'map'),
              ),
              ListTile(
                leading: const Icon(Icons.my_location, color: _kPrimary),
                title: const Text('Usar mi ubicación actual'),
                onTap: () => Navigator.pop(ctx, 'auto'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    if (opcion == 'auto') _getCurrentLocation(isOrigen: isOrigen);
    if (opcion == 'map') _showMapPicker(isOrigen: isOrigen);
    if (opcion == 'search') _searchAddress(isOrigen: isOrigen);
  }

  static const String _recentKey = 'recent_addresses';

  Future<void> _searchAddress({bool isOrigen = true}) async {
    final ctrl = TextEditingController();
    try {
      final recent = await _loadRecentSearches();
      if (!mounted) return;
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isOrigen ? 'Dirección de recogida' : 'Dirección de entrega'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Ej: Calle 10 # 43-20, Medellín',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Buscar'),
            ),
          ],
        ),
      );

      if (result == null || result.trim().isEmpty) return;
      if (!mounted) return;

      setState(() => isOrigen ? _resolviendoOrigen = true : _resolviendoDestino = true);
      final List<dynamic> data;
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(result)}&format=json&limit=5&accept-language=es',
        );
        final res = await _nominatimGet(uri);
        if (res.statusCode != 200) {
          if (mounted) _snack('No se pudo buscar la dirección (${res.statusCode}). Intenta de nuevo.');
          return;
        }
        data = jsonDecode(res.body) as List<dynamic>;
      } finally {
        if (mounted) setState(() => isOrigen ? _resolviendoOrigen = false : _resolviendoDestino = false);
      }

      if (data.isEmpty) {
        if (mounted) _snack('No encontramos esa dirección. Prueba con otra o elige en el mapa.');
        return;
      }

      if (!mounted) return;

      final allResults = [...recent, ...data.cast<Map<String, dynamic>>()];
      final recentCount = recent.length;

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Selecciona una dirección'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allResults.length,
              itemBuilder: (_, i) {
                final isRecent = i < recentCount;
                final item = allResults[i];
                if (isRecent && i == 0 && recentCount > 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('RECIENTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      ),
                      _addressTile(item, ctx),
                    ],
                  );
                }
                if (isRecent && i == recentCount - 1 && i + 1 < allResults.length) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _addressTile(item, ctx),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('RESULTADOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      ),
                    ],
                  );
                }
                return _addressTile(item, ctx);
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ],
        ),
      );

      if (selected != null && mounted) {
        _saveRecentSearch(selected);
        final lat = double.tryParse(selected['lat']?.toString() ?? '');
        final lon = double.tryParse(selected['lon']?.toString() ?? '');
        if (lat != null && lon != null) {
          _setPunto(isOrigen, LatLng(lat, lon), selected['display_name'] as String? ?? result);
        }
      }
    } catch (e) {
      LoggerService.instance.warning('nuevo_envio._searchAddress error', e);
      if (mounted) _snack('No se pudo buscar la dirección. Revisa tu conexión o elige en el mapa.');
    } finally {
      ctrl.dispose();
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentKey);
      if (raw == null) return [];
      return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRecentSearch(Map<String, dynamic> address) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentKey) ?? [];
    final id = address['place_id'] ?? address['display_name'];
    raw.removeWhere((e) {
      try { return (jsonDecode(e) as Map<String, dynamic>)['place_id'] == id; } catch (_) { return false; }
    });
    raw.insert(0, jsonEncode(address));
    if (raw.length > 10) raw.removeLast();
    await prefs.setStringList(_recentKey, raw);
  }

  Widget _addressTile(Map<String, dynamic> item, BuildContext ctx) {
    return ListTile(
      leading: const Icon(Icons.location_on, color: _kPrimary),
      title: Text(item['display_name'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.pop(ctx, item),
    );
  }

  void _showMapPicker({bool isOrigen = true}) {
    final inicial = (isOrigen ? _origenLatLng : _destinoLatLng) ?? _center;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Toca el mapa para marcar el ${isOrigen ? "origen" : "destino"}'),
        // Ancho explícito: AlertDialog mide el ancho intrínseco del contenido y FlutterMap no lo soporta.
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: inicial,
              initialZoom: 14,
              onTap: (tap, latLng) {
                Navigator.pop(ctx);
                if (mounted) _elegirEnMapa(latLng, isOrigen: isOrigen);
              },
            ),
            children: [
              _tileLayer,
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  // ── Validación y envío ────────────────────────────────────────────────────

  int? get _precio {
    final v = int.tryParse(_precioCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    return (v == null || v <= 0) ? null : v;
  }

  bool get _origenOk => _origenLatLng != null && _origenCtrl.text.trim().isNotEmpty;
  bool get _destinoOk => _destinoLatLng != null && _destinoCtrl.text.trim().isNotEmpty;
  bool get _formValido => _origenOk && _destinoOk && _precio != null;

  List<String> get _faltantes => [
        if (!_origenOk) 'origen',
        if (!_destinoOk) 'destino',
        if (_precio == null) 'precio',
      ];

  Future<void> _solicitar() async {
    if (_loading) return; // doble toque
    if (!_origenOk || !_destinoOk) {
      _snack('Selecciona origen y destino');
      return;
    }
    final precio = _precio;
    if (precio == null) {
      setState(() => _precioTocado = true);
      _snack('Ingresa un precio válido');
      return;
    }

    setState(() => _loading = true);
    final body = {
      'origen': {
        'direccion': _origenCtrl.text.trim(),
        'lat': _origenLatLng!.latitude,
        'lng': _origenLatLng!.longitude,
      },
      'destino': {
        'direccion': _destinoCtrl.text.trim(),
        'lat': _destinoLatLng!.latitude,
        'lng': _destinoLatLng!.longitude,
      },
      'descripcion': _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
      'precioCliente': precio,
    };
    try {
      // Misma clave si el usuario reintenta tras un fallo de red: el backend
      // no crea un segundo viaje.
      await ApiClient.instance.requestTrip(body, idempotencyKey: _requestKey.keyFor(body));
      _requestKey.settle();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RastreoScreen()));
        });
      }
    } catch (e) {
      _requestKey.settle(e);
      if (mounted) _handleRequestError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleRequestError(Object e) {
    if (e is ApiException && e.statusCode == 409) {
      // El backend responde 409 { error, viajeId } cuando el cliente ya tiene
      // un viaje activo: ofrecer ir directamente al seguimiento.
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ya tienes un viaje activo'),
          content: Text(
            e.message.isNotEmpty
                ? e.message
                : 'Debes cancelarlo o esperar a que termine antes de solicitar otro.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RastreoScreen()),
                );
              },
              child: const Text('Ver mi viaje'),
            ),
          ],
        ),
      );
      return;
    }
    _snack(e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', ''));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static double _distanciaKm(LatLng a, LatLng b) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180.0;
    final dLat = rad(b.latitude - a.latitude);
    final dLon = rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.asin(math.sqrt(h));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.mostrarMapa) ...[
                      _buildMapSection(),
                      const SizedBox(height: 20),
                    ],
                    const _StepLabel(numero: 1, label: 'Ruta'),
                    const SizedBox(height: 8),
                    _buildRutaCard(),
                    const SizedBox(height: 24),
                    const _StepLabel(numero: 2, label: '¿Qué vas a enviar?', opcional: true),
                    const SizedBox(height: 8),
                    _buildDescripcion(),
                    const SizedBox(height: 24),
                    const _StepLabel(numero: 3, label: 'Tu oferta'),
                    const SizedBox(height: 8),
                    _buildPrecio(),
                    const SizedBox(height: 28),
                    _buildBoton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Colors.black87),
            ),
          ),
          const Text(
            'Nuevo envío',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87, letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildRutaCard() {
    final o = _origenLatLng;
    final d = _destinoLatLng;
    final cargandoOrigen = _loadingLocation && _locParaOrigen;
    final cargandoDestino = _loadingLocation && !_locParaOrigen;
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _PuntoRow(
            key: const Key('fila_origen'),
            color: _kOrigen,
            icon: Icons.trip_origin,
            label: 'Origen',
            placeholder: '¿Dónde recogemos?',
            valor: _origenOk ? _origenCtrl.text : null,
            estado: cargandoOrigen
                ? 'Obteniendo tu ubicación…'
                : (_resolviendoOrigen ? 'Buscando la dirección…' : null),
            onTap: () => _elegirPunto(isOrigen: true),
          ),
          if (_locError != null && _locParaOrigen) _buildLocError(isOrigen: true),
          if (_origenOk && _origenFueraDeCobertura)
            Padding(
              key: const Key('aviso_fuera_cobertura'),
              padding: const EdgeInsets.fromLTRB(52, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Este punto de recogida está fuera de nuestra zona de cobertura. '
                      'Elige otro origen.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, indent: 52, color: Color(0xFFF0F0F0)),
          _PuntoRow(
            key: const Key('fila_destino'),
            color: _kDestino,
            icon: Icons.location_on,
            label: 'Destino',
            placeholder: '¿A dónde lo llevamos?',
            valor: _destinoOk ? _destinoCtrl.text : null,
            estado: cargandoDestino
                ? 'Obteniendo tu ubicación…'
                : (_resolviendoDestino ? 'Buscando la dirección…' : null),
            onTap: () => _elegirPunto(isOrigen: false),
          ),
          if (_locError != null && !_locParaOrigen) _buildLocError(isOrigen: false),
          if (o != null && d != null) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.route_outlined, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Distancia aprox.: ${_formatKm(_distanciaKm(o, d))} en línea recta',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  Widget _buildLocError({required bool isOrigen}) {
    final acciones = <Widget>[
      OutlinedButton.icon(
        key: const Key('btn_reintentar_ubicacion'),
        onPressed: () => _getCurrentLocation(isOrigen: isOrigen),
        icon: const Icon(Icons.my_location, size: 16),
        label: const Text('Reintentar'),
      ),
      if (_locIssue == LocationIssue.serviceDisabled)
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kPrimary),
          onPressed: LocationPermissionHelper.openLocationSettings,
          child: const Text('Activar ubicación'),
        ),
      if (_locIssue == LocationIssue.deniedForever)
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kPrimary),
          onPressed: LocationPermissionHelper.openAppSettings,
          child: const Text('Abrir ajustes'),
        ),
      TextButton.icon(
        onPressed: () => _searchAddress(isOrigen: isOrigen),
        icon: const Icon(Icons.search, size: 16),
        label: const Text('Buscar dirección'),
      ),
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFFC2410C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_locError También puedes buscar la dirección o tocar el mapa.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7C2D12), height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: acciones),
        ],
      ),
    );
  }

  Widget _buildDescripcion() {
    return _Card(
      child: TextField(
        controller: _descripcionCtrl,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        minLines: 1,
        maxLines: 4,
        maxLength: 300,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          counterText: '',
          hintText: 'Ej: 3 cajas medianas, una nevera, 200 kg aprox.',
        ),
      ),
    );
  }

  Widget _buildPrecio() {
    final error = _precioTocado && _precio == null ? 'Ingresa el valor que ofreces (mayor a \$0).' : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: error != null ? _kDestino : _kBorde, width: error != null ? 1.4 : 1),
          ),
          child: Row(
            children: [
              const Text('\$', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black54)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('campo_precio'),
                  controller: _precioCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                  inputFormatters: [MilesInputFormatter()],
                  onChanged: (_) => setState(() => _precioTocado = true),
                ),
              ),
              Text('COP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500])),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          error ?? 'Es el valor que propones. Los conductores pueden aceptarlo o enviarte una contraoferta.',
          style: TextStyle(fontSize: 12, height: 1.3, color: error != null ? _kDestino : Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildBoton() {
    final faltan = _faltantes;
    final habilitado = !_loading && _formValido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton(
            key: const Key('btn_solicitar'),
            onPressed: habilitado ? _solicitar : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFBFD0F5),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Enviando solicitud…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  )
                : const Text('Solicitar viaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        if (faltan.isNotEmpty && !_loading) ...[
          const SizedBox(height: 8),
          Text(
            'Para continuar indica: ${_listaHumana(faltan)}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  static String _listaHumana(List<String> items) {
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
  }

  Widget _buildMapSection() {
    final o = _origenLatLng;
    final d = _destinoLatLng;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: _mapOptions,
            children: [
              _tileLayer,
              if (o != null && d != null)
                PolylineLayer(polylines: [
                  Polyline(points: [o, d], color: _kPrimary.withValues(alpha: 0.6), strokeWidth: 3),
                ]),
              MarkerLayer(markers: [
                if (o != null)
                  Marker(point: o, child: const Icon(Icons.trip_origin, color: _kOrigen, size: 28)),
                if (d != null)
                  Marker(
                    point: d,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: _kDestino, size: 34),
                  ),
              ]),
            ],
          ),
          Positioned(
            right: 10,
            top: 10,
            child: _MapButton(
              tooltip: 'Usar mi ubicación como origen',
              loading: _loadingLocation,
              onTap: () => _getCurrentLocation(isOrigen: true),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            right: 60,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 14, color: Colors.black54),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Toca el mapa para marcar un punto',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Formatea dígitos con separador de miles colombiano: 150000 -> 150.000.
String formatearMiles(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (digits.isEmpty) return '';
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

class MilesInputFormatter extends TextInputFormatter {
  static const int maxDigitos = 9;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigitos) return oldValue;
    final text = formatearMiles(digits);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _StepLabel extends StatelessWidget {
  final int numero;
  final String label;
  final bool opcional;
  const _StepLabel({required this.numero, required this.label, this.opcional = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
          child: Text('$numero', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
        if (opcional) ...[
          const SizedBox(width: 6),
          Text('(opcional)', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ],
    );
  }
}

class _PuntoRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String placeholder;
  final String? valor;
  final String? estado;
  final VoidCallback onTap;

  const _PuntoRow({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.placeholder,
    required this.valor,
    required this.estado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vacio = valor == null;
    return Semantics(
      button: true,
      label: '$label: ${valor ?? placeholder}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(fontSize: 11, letterSpacing: 0.4, color: Colors.grey[500], fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      valor ?? placeholder,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: vacio ? FontWeight.w500 : FontWeight.w600,
                        color: vacio ? Colors.grey[500] : Colors.black87,
                      ),
                    ),
                    if (estado != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(estado!, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(vacio ? Icons.add_circle_outline : Icons.edit_outlined, size: 20, color: vacio ? _kPrimary : Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final String tooltip;
  final bool loading;
  final VoidCallback onTap;
  const _MapButton({required this.tooltip, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 2,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 20, color: _kPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorde),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
