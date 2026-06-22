import 'dart:math';
import 'package:flutter/material.dart';
import 'oferta_aceptada_screen.dart';

class OfertasRecibidasScreen extends StatefulWidget {
  final List<Map<String, dynamic>> ofertas;
  final Map<String, dynamic> trip;
  final Future<void> Function(String offerId) onAccept;
  final Future<void> Function(String offerId) onReject;

  const OfertasRecibidasScreen({
    super.key,
    required this.ofertas,
    required this.trip,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<OfertasRecibidasScreen> createState() => _OfertasRecibidasScreenState();
}

class _OfertasRecibidasScreenState extends State<OfertasRecibidasScreen> {
  late List<Map<String, dynamic>> _offers;
  String? _acceptingId;

  @override
  void initState() {
    super.initState();
    _offers = List.from(widget.ofertas);
  }

  Color _avatarColor(String name) {
    final hash = name.hashCode;
    final colors = [
      const Color(0xFF7B5EA7),
      const Color(0xFF4A90A4),
      const Color(0xFF8B6914),
      const Color(0xFFC0392B),
      const Color(0xFF2E86AB),
      const Color(0xFFA23B72),
    ];
    return colors[(hash % colors.length).abs()];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatPrecio(num monto) {
    return '\$${monto.toStringAsFixed(0)}';
  }

  Future<void> _rechazar(String offerId, int index) async {
    try {
      await widget.onReject(offerId);
      if (mounted) {
        setState(() => _offers.removeAt(index));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al rechazar oferta')),
        );
      }
    }
  }

  Future<void> _aceptar(String offerId) async {
    setState(() => _acceptingId = offerId);
    try {
      await widget.onAccept(offerId);
      if (!mounted) return;

      final offer = _offers.cast<Map<String, dynamic>?>().firstWhere(
        (o) => o?['id']?.toString() == offerId,
        orElse: () => null,
      );
      final conductor = offer?['conductor'] as Map<String, dynamic>?;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfertaAceptadaScreen(
            conductorNombre: conductor?['nombre'] as String? ?? 'Conductor',
            camion: conductor?['tipoVehiculo'] as String? ?? '',
            placa: offer?['placa'] as String? ?? conductor?['placa'] as String? ?? '',
            rating: (conductor?['rating'] as num?)?.toDouble() ?? 0,
            onVerSeguimiento: () => Navigator.pop(context),
          ),
        ),
      );

      if (mounted) Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _acceptingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presupuesto = num.tryParse(widget.trip['precioEstimado']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Colors.black87),
                    ),
                  ),
                  Text(
                    'Ofertas recibidas (${_offers.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            if (_offers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No hay ofertas disponibles', style: TextStyle(color: Colors.black45, fontSize: 15)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _offers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final offer = _offers[i];
                    final conductor = offer['conductor'] as Map<String, dynamic>?;
                    final nombre = conductor?['nombre'] as String? ?? 'Conductor';
                    final camion = '${conductor?['tipoVehiculo'] ?? ''} · ${offer['placa'] ?? conductor?['placa'] ?? ''}';
                    final monto = num.tryParse(offer['monto']?.toString() ?? '') ?? 0;
                    final diff = presupuesto > 0 ? ((monto - presupuesto) / presupuesto * 100).round() : 0;
                    final isAccepting = _acceptingId == offer['id'];

                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _avatarColor(nombre),
                                child: Text(
                                  _initials(nombre),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                                    const SizedBox(height: 3),
                                    Text(
                                      camion,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w400),
                                    ),
                                    if (diff != 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          diff <= 0 ? 'Bajo presupuesto' : '+$diff% sobre presupuesto',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: diff <= 10 ? const Color(0xFF22C55E) : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatPrecio(monto),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isAccepting ? null : () => _rechazar(offer['id']?.toString() ?? '', i),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  child: const Text('Rechazar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isAccepting ? null : () => _aceptar(offer['id']?.toString() ?? ''),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                  child: isAccepting
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Aceptar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: Text(
                'Elige la mejor oferta para ti.',
                style: TextStyle(fontSize: 13, color: const Color(0xFF2563EB), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
