import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../contracts/solicitud.dart' show solicitudSigueAbierta, textoDistanciaRecogida;
import '../services/api/trip_service.dart';
import '../core/formato_dinero.dart';

export '../contracts/solicitud.dart' show solicitudSigueAbierta;

/// Tarjeta tipo Uber para una nueva solicitud de viaje cercana.
/// Muestra precio, recogida, destino, distancia hasta la recogida y una cuenta
/// atrás. Completa los datos con GET /api/trips/:id (ruta existente).
class SolicitudViajeSheet extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> resumen; // payload de trip:nearby o del polling
  final double? conductorLat;
  final double? conductorLng;
  final VoidCallback onVer;
  final Duration duracion;

  const SolicitudViajeSheet({
    super.key,
    required this.tripId,
    required this.resumen,
    required this.onVer,
    this.conductorLat,
    this.conductorLng,
    this.duracion = const Duration(seconds: 25),
  });

  @override
  State<SolicitudViajeSheet> createState() => _SolicitudViajeSheetState();
}

class _SolicitudViajeSheetState extends State<SolicitudViajeSheet> {
  static const _azul = Color(0xFF1A3C6E);
  static const _verde = Color(0xFF16A34A);
  static const _gris = Color(0xFF6B7280);
  static const _oscuro = Color(0xFF1A1A2E);

  Map<String, dynamic>? _detalle;
  late int _restante;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restante = widget.duracion.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_restante <= 1) {
        t.cancel();
        Navigator.of(context).maybePop();
        return;
      }
      setState(() => _restante--);
      // Cada 5 s se confirma que la solicitud sigue abierta: si ya la tomó
      // alguien (incluido este conductor) o se canceló, el aviso se cierra.
      if (_restante % 5 == 0) _cargarDetalle();
    });
    _cargarDetalle();
  }

  void _cargarDetalle() {
    TripService.getTripDetail(widget.tripId).then((d) {
      if (!mounted) return;
      if (!solicitudSigueAbierta(d['estado'])) {
        _timer?.cancel();
        Navigator.of(context).maybePop();
        return;
      }
      setState(() => _detalle = d);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  dynamic _campo(String k) => _detalle?[k] ?? widget.resumen[k];

  String _direccion(dynamic v) {
    if (v is String) return v;
    if (v is Map) return (v['direccion'] as String?) ?? '';
    return '';
  }

  num? _num(dynamic v) => v == null ? null : num.tryParse(v.toString());

  String _dinero(num? v) => formatearPesos(v, siNulo: '—');

  double? _kmHastaRecogida() {
    final o = _campo('origen');
    if (o is! Map || widget.conductorLat == null || widget.conductorLng == null) return null;
    final lat = _num(o['lat'])?.toDouble();
    final lng = _num(o['lng'])?.toDouble();
    if (lat == null || lng == null) return null;
    const r = 6371.0;
    final dLat = (lat - widget.conductorLat!) * pi / 180;
    final dLng = (lng - widget.conductorLng!) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(widget.conductorLat! * pi / 180) * cos(lat * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final precio = _num(_campo('precioEstimado')) ?? _num(_campo('precioCliente'));
    final origen = _direccion(_campo('origen'));
    final destino = _direccion(_campo('destino'));
    final carga = (_campo('descripcion') ?? _campo('carga'))?.toString() ?? '';
    final minutos = _num(_campo('tiempoEstimado'))?.toInt();
    final km = _kmHastaRecogida();
    final progreso = _restante / widget.duracion.inSeconds;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _verde.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Nueva solicitud',
                      style: TextStyle(color: _verde, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const Spacer(),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progreso,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey.shade200,
                        color: _restante <= 5 ? Colors.red : _azul,
                      ),
                      Text('$_restante', style: const TextStyle(fontWeight: FontWeight.w800, color: _oscuro)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_dinero(precio),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _oscuro, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (km != null) _chip(Icons.near_me_rounded, textoDistanciaRecogida(km)),
                if (minutos != null && minutos > 0) _chip(Icons.schedule_rounded, '$minutos min de viaje'),
              ],
            ),
            const SizedBox(height: 16),
            _parada(Icons.circle, _verde, 'Recogida', origen.isEmpty ? 'Cerca de ti' : origen),
            // Align: en una columna "stretch" el conector ocupaba todo el
            // ancho y se veía como una barra gris.
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 9),
                child: Container(width: 2, height: 18, color: Colors.grey.shade300),
              ),
            ),
            _parada(Icons.location_on_rounded, Colors.red, 'Destino', destino.isEmpty ? 'Cargando…' : destino),
            if (carga.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.inventory_2_outlined, size: 18, color: _gris),
                  const SizedBox(width: 8),
                  Expanded(child: Text(carga, style: const TextStyle(color: _oscuro, fontSize: 13), maxLines: 2)),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: _gris,
                    ),
                    child: const Text('Ignorar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onVer();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: _azul,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Ver y ofertar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: _azul),
          const SizedBox(width: 5),
          Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _oscuro)),
        ]),
      );

  Widget _parada(IconData icon, Color color, String titulo, String texto) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontSize: 11, color: _gris)),
              Text(texto,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _oscuro),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ],
      );
}
