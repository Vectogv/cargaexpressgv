import 'package:flutter/material.dart';

import '../../services/api/http_client.dart';
import '../../services/config_cliente_service.dart';

/// Si el cliente no responde, el backend (confirmacion_timeout_service)
/// avisa a un moderador tras `confirmacionTimeoutMin` minutos; NO confirma
/// solo. El plazo llega de GET /api/config/cliente (10 min si no está).
String avisoConfirmacionPendiente(int minutos) =>
    'Si no confirmas ni rechazas en unos $minutos minutos, un moderador revisará el cierre del viaje.';
const TextStyle estiloAvisoConfirmacion =
    TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5);

/// Aviso del plazo de confirmación con el valor configurado en el backend.
class AvisoConfirmacionPendiente extends StatelessWidget {
  final TextAlign? textAlign;
  const AvisoConfirmacionPendiente({super.key, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReglasCliente>(
      valueListenable: ConfigClienteService.instance.reglas,
      builder: (_, reglas, _) => Text(
        avisoConfirmacionPendiente(reglas.confirmacionTimeoutMin),
        style: estiloAvisoConfirmacion,
        textAlign: textAlign,
      ),
    );
  }
}

/// Mensaje en español para un fallo al confirmar o rechazar la entrega.
/// Los [ApiException] ya traen el texto del backend (o el de red del
/// HttpClient); cualquier otro error muestra un aviso genérico.
String mensajeErrorEntrega(Object error) {
  if (error is ApiException) {
    final m = error.message.trim();
    if (m.isNotEmpty) return m;
  }
  return 'No se pudo completar la acción. Revisa tu conexión e intenta de nuevo.';
}

/// Longitud mínima del motivo de rechazo (evita motivos vacíos o de una letra).
const int motivoRechazoMinimo = 5;

/// Valida el motivo del diálogo de rechazo; `null` si es válido.
String? validarMotivoRechazo(String? valor) {
  final texto = (valor ?? '').trim();
  if (texto.isEmpty) return 'Escribe el motivo del rechazo.';
  if (texto.length < motivoRechazoMinimo) {
    return 'Describe el motivo con al menos $motivoRechazoMinimo caracteres.';
  }
  return null;
}

class ConfirmarEntregaScreen extends StatefulWidget {
  final Future<void> Function() onConfirmar;
  final Future<void> Function(String motivo)? onRechazar;
  final String? montoFinal;
  final bool fueraDeRango;
  final double distanciaKm;
  final String? justificacionConductor;

  /// El viaje ya está en disputa: se muestra ese estado en vez de los
  /// botones de confirmar/rechazar.
  final bool enDisputa;

  /// Acción de "Volver al inicio" en el estado de disputa. Si no se da, se
  /// vuelve a la primera ruta.
  final VoidCallback? onVolverAlInicio;

  const ConfirmarEntregaScreen({
    super.key,
    required this.onConfirmar,
    this.onRechazar,
    this.montoFinal,
    this.fueraDeRango = false,
    this.distanciaKm = 0.0,
    this.justificacionConductor,
    this.enDisputa = false,
    this.onVolverAlInicio,
  });

  @override
  State<ConfirmarEntregaScreen> createState() => _ConfirmarEntregaScreenState();
}

class _ConfirmarEntregaScreenState extends State<ConfirmarEntregaScreen> {
  static const _verde = Color(0xFF22C55E);
  static const _naranja = Color(0xFFF97316);
  static const _fondo = Color(0xFFF5F7FA);

  bool _loading = false;
  // Rechazo enviado con éxito: el viaje quedó en disputa y ya no se puede
  // confirmar ni rechazar desde aquí.
  bool _rechazada = false;

  bool get _enDisputa => _rechazada || widget.enDisputa;

  /// Ejecuta la acción con ambos botones bloqueados. Devuelve `true` si
  /// terminó sin error. Si falla, avisa en español y los botones vuelven a
  /// estar disponibles para reintentar.
  Future<bool> _ejecutar(Future<void> Function() accion) async {
    setState(() => _loading = true);
    try {
      await accion();
      return true;
    } catch (e) {
      debugPrint('ConfirmarEntrega: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(mensajeErrorEntrega(e))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleConfirmar() async {
    if (_loading || _enDisputa) return;
    await _ejecutar(widget.onConfirmar);
  }

  Future<void> _handleRechazar() async {
    if (_loading || _enDisputa) return;
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const RechazarEntregaDialog(),
    );

    final onRechazar = widget.onRechazar;
    if (motivo == null || motivo.isEmpty || onRechazar == null || !mounted) return;
    final ok = await _ejecutar(() => onRechazar(motivo));
    if (!ok || !mounted) return;
    // El backend dejó el viaje en 'disputa': se muestra ese estado aunque el
    // padre no navegue a otra pantalla.
    setState(() => _rechazada = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Rechazaste la entrega. Un moderador revisará tu caso.'),
      ));
  }

  void _volverAlInicio() {
    final cb = widget.onVolverAlInicio;
    if (cb != null) {
      cb();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_enDisputa) {
      return Scaffold(
        backgroundColor: _fondo,
        body: SafeArea(
          child: _DisputaAbiertaPanel(onVolverAlInicio: _volverAlInicio),
        ),
      );
    }
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
                '¿Todo está en orden?',
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
              const SizedBox(height: 10),
              const AvisoConfirmacionPendiente(textAlign: TextAlign.center),
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
                    color: _verde,
                  ),
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const Key('btn_confirmar_entrega'),
                  onPressed: _loading ? null : _handleConfirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _verde.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text(
                          'Sí, confirmar entrega',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  key: const Key('btn_rechazar_entrega'),
                  onPressed: _loading ? null : _handleRechazar,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _loading ? const Color(0xFFFDBA74) : _naranja, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _naranja))
                      : const Text(
                          'Rechazar entrega',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _naranja,
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

/// Estado "Disputa abierta" que reemplaza a los botones de confirmar y
/// rechazar cuando el viaje quedó en disputa (mismo estilo que las pantallas
/// de llegada y de conductor en la zona).
class _DisputaAbiertaPanel extends StatelessWidget {
  final VoidCallback onVolverAlInicio;
  const _DisputaAbiertaPanel({required this.onVolverAlInicio});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.gavel_rounded, color: Colors.white, size: 26),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Disputa abierta',
                                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                            SizedBox(height: 3),
                            Text('Rechazaste la entrega. Un moderador revisará tu caso.',
                                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                          ],
                        ),
                      ),
                    ],
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Qué sigue?',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                      SizedBox(height: 8),
                      Text(
                        'Un moderador revisará tu motivo y la evidencia del conductor. '
                        'Te avisaremos la resolución; mientras tanto no necesitas hacer nada más '
                        'y el viaje no se puede confirmar ni cerrar.',
                        style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  key: const Key('btn_disputa_volver_inicio'),
                  onPressed: onVolverAlInicio,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Volver al inicio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Diálogo "Rechazar entrega": motivo obligatorio (validado), se desplaza
/// con el teclado y devuelve el motivo escrito (o `null` si se cancela).
class RechazarEntregaDialog extends StatefulWidget {
  const RechazarEntregaDialog({super.key});

  @override
  State<RechazarEntregaDialog> createState() => _RechazarEntregaDialogState();
}

class _RechazarEntregaDialogState extends State<RechazarEntregaDialog> {
  static const _naranja = Color(0xFFF97316);

  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_motivoCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Icon(Icons.report_problem_outlined, color: Color(0xFFEA580C), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Rechazar entrega',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Cuéntanos qué pasó con la carga. Se abrirá una disputa y un moderador la revisará.',
                style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.45),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('campo_motivo_rechazo'),
                controller: _motivoCtrl,
                autofocus: true,
                maxLines: 4,
                minLines: 3,
                maxLength: 300,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                validator: validarMotivoRechazo,
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: 'Ej.: faltan dos cajas, la carga llegó dañada…',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  contentPadding: const EdgeInsets.all(14),
                  counterStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: const Key('btn_cancelar_rechazo'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('btn_confirmar_rechazo'),
                        onPressed: _enviar,
                        style: FilledButton.styleFrom(
                          backgroundColor: _naranja,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Rechazar entrega', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
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
