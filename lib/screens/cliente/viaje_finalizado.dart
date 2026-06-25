import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'calificar_conductor_screen.dart';

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
    final origen = widget.trip['origen'] as Map<String, dynamic>?;
    final destino = widget.trip['destino'] as Map<String, dynamic>?;
    final monto = (widget.trip['precioFinal'] as num?)?.toDouble() ?? (widget.trip['monto'] as num?)?.toDouble() ?? 0;
    final comision = monto * 0.10;
    final total = monto - comision;

    String f(double v) {
      final clamped = v.abs();
      final parts = clamped.toStringAsFixed(0).split('.');
      final intPart = parts[0];
      final buf = StringBuffer();
      for (var i = 0; i < intPart.length; i++) {
        if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
        buf.write(intPart[i]);
      }
      return buf.toString();
    }

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
                    _ResumenRow(label: 'Origen', value: origen?['direccion'] as String? ?? 'N/A'),
                    const SizedBox(height: 10),
                    _ResumenRow(label: 'Destino', value: destino?['direccion'] as String? ?? 'N/A'),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
                    const SizedBox(height: 16),
                    _ResumenRow(label: 'Precio acordado', value: '\$${f(monto)}'),
                    const SizedBox(height: 10),
                    _ResumenRow(label: 'Comisi\u00f3n (10%)', value: '- \$${f(comision)}', valueColor: const Color(0xFFEF4444)),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFE5E7EB), thickness: 1, height: 1),
                    const SizedBox(height: 14),
                    _ResumenRow(label: 'Total pagado', value: '\$${f(total)}', labelBold: true, valueBold: true),
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
  final Color? valueColor;
  final bool labelBold;
  final bool valueBold;

  const _ResumenRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelBold = false,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: const Color(0xFF6B7280), fontWeight: labelBold ? FontWeight.w700 : FontWeight.w400)),
        Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? Colors.black, fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }
}
