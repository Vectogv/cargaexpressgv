import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../contracts/calificacion.dart';
import '../../widgets/mapa_viaje.dart';

class ConductorEnLaZonaScreen extends StatelessWidget {
  final Map<String, dynamic> conductor;
  final VoidCallback? onChat;
  final VoidCallback? onCall;
  final LatLng? origen;
  final LatLng? ubicacionConductor;

  const ConductorEnLaZonaScreen({
    super.key,
    required this.conductor,
    this.origen,
    this.ubicacionConductor,
    this.onChat,
    this.onCall,
  });

  static const _azul = Color(0xFF2563EB);
  static const _fondo = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    final nombre = conductor['nombre'] as String? ?? 'Conductor';
    final rating = etiquetaCalificacionConductor(conductor);
    final placa = conductor['placa']?.toString();
    final vehiculo = conductor['tipoVehiculo']?.toString();
    final inicial = nombre.trim().isEmpty ? '?' : nombre.trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Conductor en la zona',
          style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado: qué pasa y qué debe hacer el cliente.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¡Tu conductor llegó!',
                            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Text('Está en la zona de recogida. Sal a encontrarlo y entrégale la carga.',
                            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 200,
                child: MapaViaje(
                  origen: origen,
                  vehiculo: ubicacionConductor,
                  dibujarVehiculo: true,
                  tipoVehiculo: vehiculo,
                  etiquetaVehiculo: 'En la zona',
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: Text(inicial,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _azul)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 17),
                          const SizedBox(width: 3),
                          Text(rating, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                          if (vehiculo != null && vehiculo.isNotEmpty) ...[
                            const Text('  ·  ', style: TextStyle(color: Color(0xFF9CA3AF))),
                            Flexible(
                              child: Text(vehiculo[0].toUpperCase() + vehiculo.substring(1),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                            ),
                          ],
                        ]),
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
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: Color(0xFFEA580C), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Antes de entregar la carga, verifica que la placa coincida con la del vehículo.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF9A3412), height: 1.35)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Acciones fijas abajo y sobre la barra de navegación.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: onChat,
                      style: FilledButton.styleFrom(
                        backgroundColor: _azul,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _azul,
                        side: const BorderSide(color: _azul, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.phone),
                      label: const Text('Llamar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}