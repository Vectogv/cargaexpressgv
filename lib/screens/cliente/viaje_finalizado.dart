import 'package:flutter/material.dart';
import 'calificar_conductor_screen.dart';
import '../../core/formato_dinero.dart';

class ViajeFinalizado extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Map<String, dynamic> conductor;

  const ViajeFinalizado({
    super.key,
    required this.trip,
    required this.conductor,
  });

  @override
  State<ViajeFinalizado> createState() => _ViajeFinalizadoState();
}

class _ViajeFinalizadoState extends State<ViajeFinalizado> {
  void _calificar() {
    final c = widget.conductor;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalificarConductorScreen(
          conductor: c,
          tripId: (widget.trip['id'] ?? widget.trip['_id'] ?? '').toString(),
          onSubmitted: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
    );
  }

  void _volverAlInicio() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final origen = widget.trip['origen'];
    final destino = widget.trip['destino'];
    String direccion(dynamic lugar) =>
        (lugar is Map ? lugar['direccion']?.toString() : null) ?? 'N/A';
    double? precio(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    // El cliente paga el precio acordado completo: la comisión de la
    // plataforma se descuenta al conductor y no se muestra aquí.
    final monto = precio(widget.trip['precioFinal']) ??
        precio(widget.trip['monto']) ??
        precio(widget.trip['precioEstimado']);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                'Viaje finalizado',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              const SizedBox(height: 32),
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E), shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x3322C55E), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                '\u00a1Viaje finalizado!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gracias por usar CargaExpress GV.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen del viaje', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                    const SizedBox(height: 14),
                    _ResumenRow(label: 'Origen', value: direccion(origen)),
                    const SizedBox(height: 10),
                    _ResumenRow(label: 'Destino', value: direccion(destino)),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
                    const SizedBox(height: 14),
                    _ResumenRow(
                      label: 'Total pagado',
                      value: formatearPesos(monto, siNulo: '\u2014'),
                      labelBold: true,
                      valueBold: true,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _calificar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Calificar al conductor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton(
                  onPressed: _volverAlInicio,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Volver al inicio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenRow extends StatelessWidget {
  final String label;
  final String value;
  final bool labelBold;
  final bool valueBold;

  const _ResumenRow({
    required this.label,
    required this.value,
    this.labelBold = false,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF6B7280), fontWeight: labelBold ? FontWeight.w700 : FontWeight.w400)),
        const SizedBox(width: 12),
        // Direcciones largas: se ajustan en vez de desbordar la fila.
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
