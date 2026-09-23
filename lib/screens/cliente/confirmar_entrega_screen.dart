import 'package:flutter/material.dart';

class ConfirmarEntregaScreen extends StatefulWidget {
  final Future<void> Function() onConfirmar;
  final Future<void> Function(String motivo)? onRechazar;
  final String? montoFinal;
  final bool fueraDeRango;
  final double distanciaKm;
  final String? justificacionConductor;

  const ConfirmarEntregaScreen({
    super.key,
    required this.onConfirmar,
    this.onRechazar,
    this.montoFinal,
    this.fueraDeRango = false,
    this.distanciaKm = 0.0,
    this.justificacionConductor,
  });

  @override
  State<ConfirmarEntregaScreen> createState() => _ConfirmarEntregaScreenState();
}

class _ConfirmarEntregaScreenState extends State<ConfirmarEntregaScreen> {
  static const String motivoRechazoPorDefecto = 'Cliente rechazó la entrega';

  bool _loading = false;
  final TextEditingController _motivoCtrl = TextEditingController();

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  /// Ejecuta la acción con el botón bloqueado. Si la acción falla o termina
  /// sin sacar al usuario de esta pantalla, los botones se reactivan para
  /// poder reintentar.
  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() => _loading = true);
    try {
      await accion();
    } catch (e) {
      debugPrint('ConfirmarEntrega: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleConfirmar() async {
    if (_loading) return;
    await _ejecutar(widget.onConfirmar);
  }

  Future<void> _handleRechazar() async {
    if (_loading) return;
    _motivoCtrl.clear();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Por favor indica el motivo del rechazo:'),
            const SizedBox(height: 16),
            TextField(
              controller: _motivoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Motivo...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final escrito = _motivoCtrl.text.trim();
              Navigator.pop(ctx, escrito.isEmpty ? motivoRechazoPorDefecto : escrito);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Confirmar rechazo'),
          ),
        ],
      ),
    );
    
    final onRechazar = widget.onRechazar;
    if (motivo != null && motivo.isNotEmpty && onRechazar != null && mounted) {
      await _ejecutar(() => onRechazar(motivo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _Illustration(),
              const SizedBox(height: 36),
              const Text(
                '\u00bfTodo est\u00e1 en orden?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Si la carga fue entregada correctamente,\nconfirma para finalizar el viaje.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.fueraDeRango) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Advertencia: El conductor está fuera de rango (${widget.distanciaKm.toStringAsFixed(1)} km del destino)',
                              style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (widget.justificacionConductor != null && widget.justificacionConductor!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Justificación del conductor: ${widget.justificacionConductor}',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (widget.montoFinal != null && widget.montoFinal!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  widget.montoFinal!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleConfirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text(
                          'S\u00ed, confirmar entrega',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading ? null : _handleRechazar,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF97316)))
                      : const Text(
                          'Rechazar entrega',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF97316),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 180,
      child: CustomPaint(
        painter: _DeliveryPainter(),
        size: const Size(200, 180),
      ),
    );
  }
}

class _DeliveryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Círculo verde de fondo
    paint.color = const Color(0xFFDCFCE7);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 70, paint);

    // checkmark blanco
    paint.color = const Color(0xFF22C55E);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 45, paint);

    paint.color = Colors.white;
    paint.strokeWidth = 4;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width / 2 - 18, size.height / 2 + 2)
      ..lineTo(size.width / 2 - 6, size.height / 2 + 14)
      ..lineTo(size.width / 2 + 18, size.height / 2 - 12);

    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
