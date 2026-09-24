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

  @override
  Widget build(BuildContext context) {
    final nombre = conductor['nombre'] as String? ?? 'Conductor';
    final rating = etiquetaCalificacionConductor(conductor);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Conductor en la zona',
          style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: MapaViaje(origen: origen, vehiculo: ubicacionConductor),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE5E7EB),
                          border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
                        ),
                        child: ClipOval(child: Icon(Icons.person, size: 32, color: const Color(0xFF9CA3AF))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                                const SizedBox(width: 4),
                                Text(rating, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _IconActionButton(icon: Icons.phone, onTap: onCall),
                          const SizedBox(width: 12),
                          _IconActionButton(icon: Icons.chat_bubble_outline, onTap: onChat),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'El conductor ha llegado a la zona de recogida.\nPuedes contactarlo para coordinar.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1))),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
            child: Row(
              children: [
                _BottomBarButton(icon: Icons.chat_bubble_outline, label: 'Chat', onTap: onChat),
                Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
                _BottomBarButton(icon: Icons.phone, label: 'Llamar', onTap: onCall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF3F4F6)),
        child: Icon(icon, size: 20, color: const Color(0xFF374151)),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _BottomBarButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF374151)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}