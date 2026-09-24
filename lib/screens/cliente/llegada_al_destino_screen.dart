import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../contracts/calificacion.dart';
import '../../widgets/mapa_viaje.dart';
import 'confirmar_entrega_screen.dart' show AvisoConfirmacionPendiente;
import '../../widgets/media_image.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Llegada al destino',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: MapaViaje(
              destino: MapaViaje.puntoDe(trip['destino']),
              vehiculo: ubicacionConductor,
              dibujarVehiculo: true,
              tipoVehiculo: conductor['tipoVehiculo']?.toString(),
              etiquetaVehiculo: 'Con tu carga',
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DriverCard(conductor: conductor),
                  const SizedBox(height: 16),
                  const Text(
                    'El conductor ha llegado al destino.\nPor favor verifica tu carga.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AvisoConfirmacionPendiente(),
                  const SizedBox(height: 20),
                  const Text(
                    'Foto de evidencia',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _EvidencePhoto(fotoUrl: trip['fotoEntrega'] as String?, cargarFoto: cargarFoto),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: onVerDetalle,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ver detalle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
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
        Column(
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
              ],
            ),
          ],
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
