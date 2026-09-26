import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../contracts/calificacion.dart';
import '../../widgets/mapa_viaje.dart';
import 'confirmar_entrega_screen.dart' show AvisoConfirmacionPendiente;
import '../../widgets/media_image.dart';
import '../shared/ui_compartida.dart';

class LlegadaAlDestinoScreen extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final Map<String, dynamic> trip;
  final VoidCallback onVerDetalle;

  /// Última posición conocida del conductor; sin ella sólo se marca el destino.
  final LatLng? ubicacionConductor;

  /// Si [trip] aún no trae `fotoEntrega` (el viaje en memoria es anterior a
  /// la subida de la foto), se consulta al backend con esto.
  final Future<String?> Function()? cargarFoto;

  const LlegadaAlDestinoScreen({
    super.key,
    required this.conductor,
    required this.trip,
    required this.onVerDetalle,
    this.ubicacionConductor,
    this.cargarFoto,
  });

  static const _verde = Color(0xFF16A34A);
  static const _azul = Color(0xFF2563EB);
  static const _fondo = Color(0xFFF5F7FA);

  static String? _direccion(dynamic p) {
    final d = p is Map ? p['direccion']?.toString() : null;
    return (d == null || d.trim().isEmpty) ? null : d;
  }

  static String? _precio(dynamic v) {
    final n = v is num ? v : num.tryParse(v?.toString() ?? '');
    if (n == null || n <= 0) return null;
    final miles = n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '\$$miles';
  }

  @override
  Widget build(BuildContext context) {
    final origen = _direccion(trip['origen']);
    final destino = _direccion(trip['destino']);
    final precio = _precio(trip['precioFinal'] ?? trip['precioEstimado']);
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Llegada al destino',
          style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoEstado(
                  titulo: '¡Tu carga llegó!',
                  detalle: 'Revisa que esté completa y en buen estado, y confirma la entrega.',
                  icono: Icons.inventory_2_rounded,
                  colores: [Color(0xFF16A34A), Color(0xFF22C55E)],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 190,
                    child: MapaViaje(
                      destino: MapaViaje.puntoDe(trip['destino']),
                      vehiculo: ubicacionConductor,
                      dibujarVehiculo: true,
                      tipoVehiculo: conductor['tipoVehiculo']?.toString(),
                      etiquetaVehiculo: 'Con tu carga',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TarjetaBlanca(child: _DriverCard(conductor: conductor)),
                const SizedBox(height: 12),
                TarjetaBlanca(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (origen != null) _Parada(icono: Icons.trip_origin, color: _verde, titulo: 'Origen', texto: origen),
                      if (origen != null && destino != null) const SizedBox(height: 12),
                      if (destino != null) _Parada(icono: Icons.location_on, color: Colors.red, titulo: 'Destino', texto: destino),
                      if (precio != null) ...[
                        const Divider(height: 26),
                        Row(children: [
                          const Expanded(
                            child: Text('Precio acordado', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                          ),
                          Text(precio, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                        ]),
                      ],
                      if (origen == null && destino == null && precio == null)
                        const Text('Revisa que la carga esté completa y en buen estado.',
                            style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TarjetaBlanca(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.photo_camera_outlined, size: 18, color: Color(0xFF6B7280)),
                        SizedBox(width: 6),
                        Text('Foto de evidencia',
                            style: TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 10),
                      _EvidencePhoto(fotoUrl: trip['fotoEntrega'] as String?, cargarFoto: cargarFoto),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
          // Acción principal siempre visible (y sobre la barra de navegación).
          BarraInferiorFija(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AvisoConfirmacionPendiente(textAlign: TextAlign.center),
                const SizedBox(height: 10),
                BotonPrincipal(
                  texto: 'Revisar y confirmar entrega',
                  icono: Icons.fact_check_outlined,
                  color: _azul,
                  onPressed: onVerDetalle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _Parada extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String texto;
  const _Parada({required this.icono, required this.color, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 2),
              Text(texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> conductor;
  const _DriverCard({required this.conductor});

  @override
  Widget build(BuildContext context) {
    final nombre = conductor['nombre'] as String? ?? 'Conductor';
    final rating = etiquetaCalificacionConductor(conductor);
    final placa = conductor['placa']?.toString();
    final vehiculo = conductor['tipoVehiculo']?.toString();

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE5E7EB),
            border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
          ),
          child: const ClipOval(
            child: Icon(Icons.person, size: 32, color: Color(0xFF9CA3AF)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (vehiculo != null && vehiculo.isNotEmpty) ...[
                  const Text('  ·  ', style: TextStyle(color: Color(0xFF9CA3AF))),
                  Flexible(
                    child: Text(
                      vehiculo[0].toUpperCase() + vehiculo.substring(1),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ],
            ),
          ],
          ),
        ),
        if (placa != null && placa.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFACC15)),
            ),
            child: Text(placa,
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 13)),
          ),
      ],
    );
  }
}

class _EvidencePhoto extends StatefulWidget {
  final String? fotoUrl;
  final Future<String?> Function()? cargarFoto;
  const _EvidencePhoto({this.fotoUrl, this.cargarFoto});

  @override
  State<_EvidencePhoto> createState() => _EvidencePhotoState();
}

class _EvidencePhotoState extends State<_EvidencePhoto> {
  Future<String?>? _remota;

  @override
  void initState() {
    super.initState();
    final local = widget.fotoUrl;
    if ((local == null || local.isEmpty) && widget.cargarFoto != null) {
      _remota = widget.cargarFoto!().catchError((_) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remota = _remota;
    if (remota == null) return _foto(widget.fotoUrl);
    return FutureBuilder<String?>(
      future: remota,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _cargando();
        return _foto(snap.data);
      },
    );
  }

  Widget _foto(String? url) {
    if (url != null && url.isNotEmpty) {
      return MediaImage(
        path: url,
        width: double.infinity,
        height: 160,
        borderRadius: BorderRadius.circular(12),
        placeholder: _buildEmptyState(),
      );
    }
    return _buildEmptyState();
  }

  Widget _cargando() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 160,
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
    );
  }

  // Sin foto: mejor mostrarlo honestamente que dibujar una imagen falsa.
  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 160,
        color: const Color(0xFFE5E7EB),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, size: 32, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 8),
            Text(
              'El conductor no adjuntó foto',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
