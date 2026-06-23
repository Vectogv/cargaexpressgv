import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/map_config.dart';
import '../../services/logger_service.dart';
import 'rastreo_screen.dart';

class NuevoEnvioScreen extends StatefulWidget {
  const NuevoEnvioScreen({super.key});

  @override
  State<NuevoEnvioScreen> createState() => _NuevoEnvioScreenState();
}

class _NuevoEnvioScreenState extends State<NuevoEnvioScreen> {
  static const String _prefOrigen = 'nuevo_envio_origen';
  static const String _prefDestino = 'nuevo_envio_destino';
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
  bool _loading = false;
  bool _loadingLocation = false;
  bool _editandoPrecio = false;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _origenCtrl.addListener(_saveDraft);
    _destinoCtrl.addListener(_saveDraft);
    _descripcionCtrl.addListener(_saveDraft);
    _precioCtrl.addListener(_saveDraft);
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    _origenCtrl.text = prefs.getString(_prefOrigen) ?? '';
    _destinoCtrl.text = prefs.getString(_prefDestino) ?? '';
    _descripcionCtrl.text = prefs.getString(_prefDescripcion) ?? '';
    _precioCtrl.text = prefs.getString(_prefPrecio) ?? '';
  }

  void _saveDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), () {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_prefOrigen, _origenCtrl.text);
        prefs.setString(_prefDestino, _destinoCtrl.text);
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
    super.dispose();
  }

  Future<void> _getCurrentLocation({bool isOrigen = true}) async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      final dir = await _reverseGeocode(latLng);

      if (mounted) {
        setState(() {
          _center = latLng;
          _mapCtrl.move(latLng, 15);
          if (isOrigen) {
            _origenLatLng = latLng;
            _origenCtrl.text = dir;
          } else {
            _destinoLatLng = latLng;
            _destinoCtrl.text = dir;
          }
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLocation = false);
        _snack('Error al obtener ubicación: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    }
  }

  Future<String> _reverseGeocode(LatLng latLng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${latLng.latitude}&lon=${latLng.longitude}&format=json&accept-language=es',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'CargaExpress/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['display_name'] as String? ?? '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      LoggerService.instance.warning('nuevo_envio._reverseGeocode error', e);
    }
    return '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng, {bool isOrigen = true}) async {
    final dir = await _reverseGeocode(latLng);
    if (mounted) {
      setState(() {
        if (isOrigen) {
          _origenLatLng = latLng;
          _origenCtrl.text = dir;
        } else {
          _destinoLatLng = latLng;
          _destinoCtrl.text = dir;
        }
      });
    }
  }

  Future<void> _searchAddress({bool isOrigen = true}) async {
    final ctrl = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Buscar dirección'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Escribe una dirección...',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          ],
        ),
      );

      if (result == null || result.trim().isEmpty) return;

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(result)}&format=json&limit=5&accept-language=es',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'CargaExpress/1.0'});
        if (res.statusCode != 200) return;

        final data = jsonDecode(res.body) as List<dynamic>;
        if (data.isEmpty) {
          if (mounted) _snack('No se encontraron resultados');
          return;
        }

        if (!mounted) return;

        final selected = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Selecciona una dirección'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: data.length,
                itemBuilder: (_, i) {
                  final item = data[i] as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF2563EB)),
                    title: Text(item['display_name'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(ctx, item),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ],
          ),
        );

        if (selected != null && mounted) {
          final lat = double.tryParse(selected['lat'] as String? ?? '');
          final lon = double.tryParse(selected['lon'] as String? ?? '');
          if (lat != null && lon != null) {
            final latLng = LatLng(lat, lon);
            setState(() {
              if (isOrigen) {
                _origenLatLng = latLng;
                _origenCtrl.text = selected['display_name'] as String? ?? result;
              } else {
                _destinoLatLng = latLng;
                _destinoCtrl.text = selected['display_name'] as String? ?? result;
              }
              _center = latLng;
              _mapCtrl.move(latLng, 15);
            });
          }
        }
    } catch (e) {
      if (mounted) _snack('Error al buscar dirección');
    } finally {
      ctrl.dispose();
    }
  }

  void _showMapPicker({bool isOrigen = true}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tocar en el mapa para ${isOrigen ? "origen" : "destino"}'),
        content: SizedBox(
          height: 300,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onTap: (tap, latLng) async {
                final dir = await _reverseGeocode(latLng);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {
                    if (isOrigen) { _origenLatLng = latLng; _origenCtrl.text = dir; }
                    else { _destinoLatLng = latLng; _destinoCtrl.text = dir; }
                  });
                }
              },
            ),
            children: [
              TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _solicitar() async {
    if (_origenCtrl.text.trim().isEmpty || _destinoCtrl.text.trim().isEmpty) {
      _snack('Ingresa origen y destino');
      return;
    }
    if (_origenLatLng == null || _destinoLatLng == null) {
      _snack('Por favor selecciona origen y destino en el mapa');
      return;
    }
    final precio = int.tryParse(_precioCtrl.text.trim());
    if (precio == null || precio <= 0) {
      _snack('Ingresa un precio válido');
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.instance.requestTrip({
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
      });

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RastreoScreen()));
        });
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          size: 28,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const Text(
                      'Nuevo envío',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Mapa
                    _buildMapSection(),

                    const SizedBox(height: 20),

                    // Card Origen / Destino
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Origen
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _getCurrentLocation(isOrigen: true),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 2),
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF2563EB),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1.5,
                                        height: 36,
                                        color: const Color(0xFFD0D0D0),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Origen',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
                                            onSelected: (v) {
                                              if (v == 'auto') _getCurrentLocation(isOrigen: true);
                                              if (v == 'map') _showMapPicker(isOrigen: true);
                                              if (v == 'search') _searchAddress(isOrigen: true);
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(value: 'auto', child: ListTile(leading: Icon(Icons.my_location, size: 18), title: Text('Ubicación automática'), dense: true, contentPadding: EdgeInsets.zero)),
                                              const PopupMenuItem(value: 'map', child: ListTile(leading: Icon(Icons.map, size: 18), title: Text('Elegir en el mapa'), dense: true, contentPadding: EdgeInsets.zero)),
                                              const PopupMenuItem(value: 'search', child: ListTile(leading: Icon(Icons.search, size: 18), title: Text('Buscar dirección'), dense: true, contentPadding: EdgeInsets.zero)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      TextField(
                                        controller: _origenCtrl,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Divider dentro del card
                          Padding(
                            padding: const EdgeInsets.only(left: 38),
                            child: Divider(
                              height: 1,
                              color: const Color(0xFFF0F0F0),
                            ),
                          ),

                          // Destino
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _getCurrentLocation(isOrigen: false),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 1.5,
                                        height: 10,
                                        color: Colors.transparent,
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Destino',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
                                            onSelected: (v) {
                                              if (v == 'auto') _getCurrentLocation(isOrigen: false);
                                              if (v == 'map') _showMapPicker(isOrigen: false);
                                              if (v == 'search') _searchAddress(isOrigen: false);
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(value: 'auto', child: ListTile(leading: Icon(Icons.my_location, size: 18), title: Text('Ubicación automática'), dense: true, contentPadding: EdgeInsets.zero)),
                                              const PopupMenuItem(value: 'map', child: ListTile(leading: Icon(Icons.map, size: 18), title: Text('Elegir en el mapa'), dense: true, contentPadding: EdgeInsets.zero)),
                                              const PopupMenuItem(value: 'search', child: ListTile(leading: Icon(Icons.search, size: 18), title: Text('Buscar dirección'), dense: true, contentPadding: EdgeInsets.zero)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      TextField(
                                        controller: _destinoCtrl,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Descripción de la carga
                    _SectionLabel(label: 'Descripción de la carga'),
                    const SizedBox(height: 8),
                    _InputCard(
                      child: TextField(
                        controller: _descripcionCtrl,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: null,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Describe tu carga...',
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Precio
                    _SectionLabel(label: 'Precio que deseas pagar'),
                    const SizedBox(height: 8),
                    _InputCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _editandoPrecio
                                ? TextField(
                                    controller: _precioCtrl,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                    ),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onSubmitted: (_) =>
                                        setState(() => _editandoPrecio = false),
                                  )
                                : Text(
                                    '\$${_precioCtrl.text}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _editandoPrecio = true),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _solicitar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text(
                                'Solicitar viaje',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 220,
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
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onTap: (tap, latLng) {
                showDialog(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Seleccionar como...'),
                    children: [
                      SimpleDialogOption(
                        onPressed: () { Navigator.pop(ctx); _onMapTap(tap, latLng, isOrigen: true); },
                        child: const ListTile(leading: Icon(Icons.trip_origin, color: Colors.green), title: Text('Origen'), dense: true, contentPadding: EdgeInsets.zero),
                      ),
                      SimpleDialogOption(
                        onPressed: () { Navigator.pop(ctx); _onMapTap(tap, latLng, isOrigen: false); },
                        child: const ListTile(leading: Icon(Icons.location_on, color: Colors.red), title: Text('Destino'), dense: true, contentPadding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                );
              },
            ),
            children: [
              TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: 'com.cargaexpress.app'),
              if (_origenLatLng != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _origenLatLng!,
                    child: const Icon(Icons.trip_origin, color: Colors.green, size: 30),
                  ),
                ]),
              if (_destinoLatLng != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _destinoLatLng!,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                  ),
                ]),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _loadingLocation
                ? const CircularProgressIndicator(strokeWidth: 2.5)
                : Column(
                    children: [
                      _mapBtn(Icons.my_location, 'Mi ubicación (origen)', () => _getCurrentLocation(isOrigen: true)),
                      const SizedBox(height: 6),
                      _mapBtn(Icons.near_me, 'Mi ubicación (destino)', () => _getCurrentLocation(isOrigen: false)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mapBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey[600],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final Widget child;
  const _InputCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
