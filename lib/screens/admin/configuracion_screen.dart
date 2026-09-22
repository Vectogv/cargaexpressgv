import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/api/http_client.dart';

/// Configuración de plataforma (solo admin):
/// - PUT /api/admin/config {nequiNumero?, nequiNombre?}
/// - GET/PUT /api/admin/config/coverage {zonasCobertura: [{nombre, activa, norte, sur, este, oeste}]}
/// - GET /api/config/banner → {activo, imagenUrl, link, texto}; PUT /api/admin/config/banner
///   {bannerActivo, bannerLink, bannerTexto}
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

String _errorText(Object e) => e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');

class _ConfigScreenState extends State<ConfigScreen> {
  final _nequiNumeroCtrl = TextEditingController();
  final _nequiNombreCtrl = TextEditingController();
  final _bannerLinkCtrl = TextEditingController();
  final _bannerTextoCtrl = TextEditingController();
  bool _bannerActivo = true;
  bool _generalSaving = false;
  bool _bannerSaving = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  @override
  void dispose() {
    _nequiNumeroCtrl.dispose();
    _nequiNombreCtrl.dispose();
    _bannerLinkCtrl.dispose();
    _bannerTextoCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _loadBanner() async {
    try {
      final data = await HttpClient.get('/api/config/banner');
      if (!mounted) return;
      setState(() {
        _bannerActivo = data['activo'] == true;
        _bannerLinkCtrl.text = (data['link'] ?? '').toString();
        _bannerTextoCtrl.text = (data['texto'] ?? '').toString();
      });
    } catch (e) {
      _snack('No se pudo cargar el banner actual: ${_errorText(e)}', error: true);
    }
  }

  Future<void> _saveGeneral() async {
    final body = <String, dynamic>{};
    if (_nequiNumeroCtrl.text.trim().isNotEmpty) body['nequiNumero'] = _nequiNumeroCtrl.text.trim();
    if (_nequiNombreCtrl.text.trim().isNotEmpty) body['nequiNombre'] = _nequiNombreCtrl.text.trim();
    if (body.isEmpty) {
      _snack('Ingresa al menos un campo', error: true);
      return;
    }
    setState(() => _generalSaving = true);
    try {
      await HttpClient.put('/api/admin/config', body: body, auth: true);
      _snack('Configuración Nequi actualizada');
    } catch (e) {
      _snack(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _generalSaving = false);
    }
  }

  Future<void> _saveBanner() async {
    setState(() => _bannerSaving = true);
    try {
      await HttpClient.put(
        '/api/admin/config/banner',
        body: {
          'bannerActivo': _bannerActivo,
          'bannerLink': _bannerLinkCtrl.text.trim(),
          'bannerTexto': _bannerTextoCtrl.text.trim(),
        },
        auth: true,
      );
      _snack('Banner guardado');
    } catch (e) {
      _snack(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _bannerSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Configuración',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGeneralSection(),
          const SizedBox(height: 16),
          const _CoverageSection(),
          const SizedBox(height: 16),
          _buildBannerSection(),
        ],
      ),
    );
  }

  Widget _saveButton({required bool saving, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        child: saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar'),
      ),
    );
  }

  Widget _buildGeneralSection() {
    return _SectionCard(
      title: 'Información de pagos (Nequi)',
      children: [
        const Text(
          'Cuenta Nequi donde los conductores pagan las comisiones.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nequiNumeroCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Número Nequi',
            hintText: 'Ej: 3001234567',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nequiNombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Titular de la cuenta',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(saving: _generalSaving, onPressed: _saveGeneral),
      ],
    );
  }

  Widget _buildBannerSection() {
    return _SectionCard(
      title: 'Banner',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Banner activo'),
          value: _bannerActivo,
          onChanged: (v) => setState(() => _bannerActivo = v),
        ),
        TextField(
          controller: _bannerTextoCtrl,
          decoration: const InputDecoration(
            labelText: 'Texto del banner',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bannerLinkCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Enlace del banner',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(saving: _bannerSaving, onPressed: _saveBanner),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Zonas de cobertura (rectángulos) ────────────────────────────────────────

const double _kmPerDeg = 111.32;
final RegExp _pointRe = RegExp(r'^(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)$');

/// "2.4448, -76.6147" (formato de Google Maps) → (lat, lng) o null.
({double lat, double lng})? _parsePoint(String text) {
  final m = _pointRe.firstMatch(text.trim());
  if (m == null) return null;
  final lat = double.parse(m.group(1)!);
  final lng = double.parse(m.group(2)!);
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat: lat, lng: lng);
}

String _fmt(num n) {
  var s = n.toStringAsFixed(5);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

double? _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

class _ZoneRow {
  final TextEditingController nombre;
  final TextEditingController desde; // esquina noroeste
  final TextEditingController hasta; // esquina sureste
  bool activa;
  final bool legacy;
  // Centro y radio originales de una zona circular. Se conservan para poder
  // guardarla tal cual: la app solo edita rectángulos, y antes reescribía el
  // círculo como su rectángulo contenedor, perdiendo el radio sin avisar.
  final double? lat;
  final double? lng;
  final double? radio;
  final String desdeInicial;
  final String hastaInicial;

  _ZoneRow({
    String nombre = '',
    String desde = '',
    String hasta = '',
    this.activa = true,
    this.legacy = false,
    this.lat,
    this.lng,
    this.radio,
  })  : nombre = TextEditingController(text: nombre),
        desde = TextEditingController(text: desde),
        hasta = TextEditingController(text: hasta),
        desdeInicial = desde,
        hastaInicial = hasta;

  bool get esCirculo => lat != null && lng != null && radio != null;

  /// ¿Se tocaron las esquinas? Solo entonces un círculo pasa a rectángulo.
  bool get esquinasEditadas =>
      desde.text.trim() != desdeInicial.trim() || hasta.text.trim() != hastaInicial.trim();

  bool get conservaCirculo => esCirculo && !esquinasEditadas;

  /// Zona del backend → fila editable. Una zona circular se muestra como el
  /// rectángulo que la contiene, pero se guarda como círculo salvo que se
  /// editen las esquinas (el radio se define desde el panel web, en el mapa).
  factory _ZoneRow.fromApi(Map<String, dynamic> z) {
    double? norte = _toDouble(z['norte']);
    double? sur = _toDouble(z['sur']);
    double? este = _toDouble(z['este']);
    double? oeste = _toDouble(z['oeste']);
    var legacy = false;
    double? centroLat;
    double? centroLng;
    double? radioKm;
    if (z['tipo'] == 'circulo' || norte == null) {
      final lat = _toDouble(z['lat'] ?? (z['centro'] is Map ? z['centro']['lat'] : null));
      final lng = _toDouble(z['lng'] ?? (z['centro'] is Map ? z['centro']['lng'] : null));
      final radio = _toDouble(z['radio']);
      if (lat != null && lng != null && radio != null) {
        centroLat = lat;
        centroLng = lng;
        radioKm = radio;
        final dLat = radio / _kmPerDeg;
        final dLng = radio / (_kmPerDeg * math.cos(lat * math.pi / 180));
        norte = lat + dLat;
        sur = lat - dLat;
        este = lng + dLng;
        oeste = lng - dLng;
        legacy = true;
      }
    }
    final hasBounds = norte != null && sur != null && este != null && oeste != null;
    return _ZoneRow(
      nombre: (z['nombre'] ?? '').toString(),
      activa: z['activa'] != false,
      desde: hasBounds ? '${_fmt(norte)}, ${_fmt(oeste)}' : '',
      hasta: hasBounds ? '${_fmt(sur)}, ${_fmt(este)}' : '',
      legacy: legacy,
      lat: centroLat,
      lng: centroLng,
      radio: radioKm,
    );
  }

  /// Dos esquinas cualesquiera → límites del rectángulo.
  Map<String, double>? get bounds {
    final a = _parsePoint(desde.text);
    final b = _parsePoint(hasta.text);
    if (a == null || b == null) return null;
    final n = math.max(a.lat, b.lat);
    final s = math.min(a.lat, b.lat);
    final e = math.max(a.lng, b.lng);
    final o = math.min(a.lng, b.lng);
    if (n == s || e == o) return null;
    return {'norte': n, 'sur': s, 'este': e, 'oeste': o};
  }

  void dispose() {
    nombre.dispose();
    desde.dispose();
    hasta.dispose();
  }
}

class _CoverageSection extends StatefulWidget {
  const _CoverageSection();

  @override
  State<_CoverageSection> createState() => _CoverageSectionState();
}

class _CoverageSectionState extends State<_CoverageSection> {
  final List<_ZoneRow> _rows = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _setRows(dynamic zonas) {
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll(HttpClient.parseListLenient(zonas).whereType<Map<String, dynamic>>().map(_ZoneRow.fromApi));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await HttpClient.get('/api/admin/config/coverage', auth: true);
      if (!mounted) return;
      setState(() => _setRows(data['zonasCobertura']));
    } catch (e) {
      if (mounted) setState(() => _loadError = _errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final nombre = r.nombre.text.trim();
      if (nombre.isEmpty) {
        _snack('Cada zona necesita un nombre', error: true);
        return;
      }
      // Zona de radio que nadie tocó: se reenvía igual para no perder el radio.
      if (r.conservaCirculo) {
        payload.add({
          'nombre': nombre,
          'activa': r.activa,
          'tipo': 'circulo',
          'lat': r.lat,
          'lng': r.lng,
          'radio': r.radio,
        });
        continue;
      }
      final b = r.bounds;
      if (b == null) {
        _snack('$nombre: revisa las dos esquinas (latitud, longitud)', error: true);
        return;
      }
      payload.add({'nombre': nombre, 'activa': r.activa, ...b});
    }
    setState(() => _saving = true);
    try {
      final data = await HttpClient.put(
        '/api/admin/config/coverage',
        body: {'zonasCobertura': payload},
        auth: true,
      );
      if (!mounted) return;
      setState(() => _setRows(data['zonasCobertura']));
      _snack('Zonas de operación guardadas');
    } catch (e) {
      _snack(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Zonas de operación',
      children: [
        const Text(
          'Cada ciudad es un rectángulo: pega la esquina noroeste (superior izquierda) y la sureste '
          '(inferior derecha) copiadas de Google Maps, p. ej. "3.5200, -76.6000". Sin zonas, se aceptan '
          'viajes en cualquier lugar.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_loadError != null)
          Row(
            children: [
              Expanded(child: Text(_loadError!, style: const TextStyle(color: Colors.red))),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          )
        else ...[
          if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin zonas configuradas', style: TextStyle(color: Colors.black54)),
            ),
          for (final r in _rows)
            _ZoneEditor(
              key: ObjectKey(r),
              row: r,
              onRemove: () => setState(() {
                _rows.remove(r);
                r.dispose();
              }),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add(_ZoneRow())),
            icon: const Icon(Icons.add),
            label: const Text('Agregar zona'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar zonas'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ZoneEditor extends StatefulWidget {
  final _ZoneRow row;
  final VoidCallback onRemove;
  const _ZoneEditor({super.key, required this.row, required this.onRemove});

  @override
  State<_ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<_ZoneEditor> {
  String? _pointError(String text) =>
      text.trim().isNotEmpty && _parsePoint(text) == null ? 'Formato: latitud, longitud' : null;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final b = r.bounds;
    String? size;
    if (b != null) {
      final alto = (b['norte']! - b['sur']!) * _kmPerDeg;
      final ancho = (b['este']! - b['oeste']!) *
          _kmPerDeg *
          math.cos(((b['norte']! + b['sur']!) / 2) * math.pi / 180);
      size = 'Área aprox. ${ancho.toStringAsFixed(1)} km × ${alto.toStringAsFixed(1)} km';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: r.nombre,
                  decoration: const InputDecoration(labelText: 'Ciudad / zona', hintText: 'Ej: Cali'),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar zona',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          if (r.esCirculo)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                r.conservaCirculo
                    ? 'Zona de radio (${_fmt(r.radio!)} km desde el centro). Aquí se muestra el rectángulo '
                        'que la contiene, pero se guarda tal cual. El radio se ajusta en el panel web, '
                        'en Configuración → Cobertura.'
                    : 'Editaste las esquinas: al guardar, esta zona dejará de ser un radio de '
                        '${_fmt(r.radio!)} km y pasará a ser rectangular.',
                style: TextStyle(
                  fontSize: 12,
                  color: r.conservaCirculo ? Colors.black54 : Colors.orange,
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: r.desde,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Desde (esquina noroeste)',
              hintText: '3.5200, -76.6000',
              helperText: 'Pega la coordenada desde Google Maps',
              errorText: _pointError(r.desde.text),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: r.hasta,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Hasta (esquina sureste)',
              hintText: '3.3300, -76.4500',
              errorText: _pointError(r.hasta.text),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Zona operando (acepta viajes)'),
            value: r.activa,
            onChanged: (v) => setState(() => r.activa = v),
          ),
          if (b != null)
            Text(
              'N ${_fmt(b['norte']!)} · S ${_fmt(b['sur']!)} · O ${_fmt(b['oeste']!)} · E ${_fmt(b['este']!)}\n$size',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}
