import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';
import '../../services/map_config.dart';
import 'rastreo_screen.dart';

class NuevoEnvioScreen extends StatefulWidget {
  const NuevoEnvioScreen({super.key});

  @override
  State<NuevoEnvioScreen> createState() => _NuevoEnvioScreenState();
}

class _NuevoEnvioScreenState extends State<NuevoEnvioScreen> {
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

  @override
  void dispose() {
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
      final res = await http.Client().get(uri, headers: {'User-Agent': 'CargaExpress/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['display_name'] as String? ?? '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
      }
    } catch (_) {}
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

  Future<void> _solicitar() async {
    if (_origenCtrl.text.trim().isEmpty || _destinoCtrl.text.trim().isEmpty) {
      _snack('Ingresa origen y destino');
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
          'lat': _origenLatLng?.latitude ?? 6.2476,
          'lng': _origenLatLng?.longitude ?? -75.5658,
        },
        'destino': {
          'direccion': _destinoCtrl.text.trim(),
          'lat': _destinoLatLng?.latitude ?? 6.2476,
          'lng': _destinoLatLng?.longitude ?? -75.5658,
        },
        'descripcion': _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        'precioCliente': precio,
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RastreoScreen()));
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nuevo envío', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSection(),
            const SizedBox(height: 16),
            _buildUbicacionField('Origen', Icons.trip_origin, _origenCtrl, true),
            const SizedBox(height: 10),
            _buildUbicacionField('Destino', Icons.location_on, _destinoCtrl, false),
            const SizedBox(height: 14),
            _buildField('Descripción de la carga', Icons.inventory_outlined, _descripcionCtrl, maxLines: 3),
            const SizedBox(height: 14),
            _buildField('Precio ofrecido (\$)', Icons.attach_money, _precioCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _solicitar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3C6E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Solicitar servicio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
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
          child: Icon(icon, size: 20, color: const Color(0xFF1A3C6E)),
        ),
      ),
    );
  }

  Widget _buildUbicacionField(String label, IconData icon, TextEditingController ctrl, bool isOrigen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF757575))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: isOrigen ? Colors.green : Colors.red),
            suffixIcon: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'auto') _getCurrentLocation(isOrigen: isOrigen);
                if (v == 'map') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Tocar en el mapa para $label'),
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
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'auto', child: ListTile(leading: Icon(Icons.my_location, size: 18), title: Text('Ubicación automática'), dense: true, contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'map', child: ListTile(leading: Icon(Icons.map, size: 18), title: Text('Elegir en el mapa'), dense: true, contentPadding: EdgeInsets.zero)),
              ],
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, IconData icon, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF757575))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1A3C6E)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}