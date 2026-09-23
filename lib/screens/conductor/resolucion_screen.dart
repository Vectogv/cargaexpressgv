import 'package:flutter/material.dart';

import '../../contracts/disputa_resultado.dart';

String? _texto(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Resolución de una disputa del conductor con los datos de
/// GET /api/disputes/:id (`resultado`, `problema`, `comentarioAdmin`).
class ResolucionScreen extends StatelessWidget {
  final Map<String, dynamic> disputa;
  final VoidCallback? onVerDetalle;
  final VoidCallback? onVolverInicio;

  const ResolucionScreen({
    super.key,
    required this.disputa,
    this.onVerDetalle,
    this.onVolverInicio,
  });

  String? get _resultadoCrudo => _texto(disputa['resultado']);

  /// Sólo se abre al resolverse la disputa: sin resultado legible se
  /// muestra "Disputa resuelta" en lugar de "Sin resultado".
  String get _resultado =>
      _resultadoCrudo == null ? 'Disputa resuelta' : etiquetaResultado(_resultadoCrudo);

  static const Color _textPrimary = Color(0xFF111111);
  static const Color _textBody = Color(0xFF333333);
  static const Color _label = Color(0xFF888888);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _blue = Color(0xFF1565C0);

  static ButtonStyle _outlineStyle() => ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? _divider : _blue,
    ),
    side: WidgetStateProperty.resolveWith(
      (s) => BorderSide(
        color: s.contains(WidgetState.disabled) ? _divider : _blue,
        width: 1.5,
      ),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Resolución',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: _textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBanner(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resultado',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _label,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _resultado,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                    if (_texto(disputa['problema']) != null)
                      ..._seccion('Problema reportado', _texto(disputa['problema'])!),
                    if (_texto(disputa['comentarioAdmin']) != null)
                      ..._seccion('Comentario del administrador', _texto(disputa['comentarioAdmin'])!),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: onVerDetalle,
                        style: _outlineStyle(),
                        child: const Text(
                          'Ver detalle',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: onVolverInicio,
                        style: _outlineStyle(),
                        child: const Text(
                          'Volver al inicio',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _seccion(String titulo, String texto) => [
        const SizedBox(height: 20),
        const Divider(color: _divider, height: 1),
        const SizedBox(height: 20),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _label,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 14,
            color: _textBody,
            height: 1.55,
          ),
        ),
      ];

  Widget _buildBanner() {
    final aFavor = _resultadoCrudo == DisputaResultado.favorConductor;
    final enContra = _resultadoCrudo == DisputaResultado.favorCliente;
    final icon = aFavor ? Icons.check_rounded : (enContra ? Icons.close_rounded : Icons.info_outline_rounded);
    final gradientColors = aFavor
        ? const [Color(0xFF2E7D32), Color(0xFF43A047)]
        : enContra
            ? const [Color(0xFFC62828), Color(0xFFE53935)]
            : const [Color(0xFF1565C0), Color(0xFF1E88E5)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Resolución',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hemos revisado la disputa\ny tomamos una decisión.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
