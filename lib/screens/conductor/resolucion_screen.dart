import 'package:flutter/material.dart';

import '../../contracts/disputa_resultado.dart';
import '../shared/ui_compartida.dart';

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
            color: ColoresApp.textoOscuro,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: ColoresApp.textoOscuro),
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
                        color: ColoresApp.chevron,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _resultado,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.azul,
                      ),
                    ),
                    // Mensaje del backend (p. ej. "Quedas bajo observación").
                    if (_texto(disputa['mensaje']) != null) ...[
                      const SizedBox(height: 8),
                      Text(_texto(disputa['mensaje'])!, style: TextStyle(fontSize: 13, color: ColoresApp.chevron, height: 1.4)),
                    ],
                    if (_texto(disputa['problema']) != null)
                      ..._seccion('Problema reportado', etiquetaProblemaDisputa(disputa['problema'])),
                    if (_texto(disputa['comentarioAdmin']) != null)
                      ..._seccion('Comentario del administrador', _texto(disputa['comentarioAdmin'])!),
                    const SizedBox(height: 32),
                    BotonSecundario(texto: 'Ver detalle', onPressed: onVerDetalle),
                    const SizedBox(height: 14),
                    BotonSecundario(texto: 'Volver al inicio', onPressed: onVolverInicio),
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
        const Divider(color: ColoresApp.divisor, height: 1),
        const SizedBox(height: 20),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ColoresApp.chevron,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 13,
            color: ColoresApp.textoSecundario,
            height: 1.55,
          ),
        ),
      ];

  Widget _buildBanner() {
    final aFavor = _resultadoCrudo == DisputaResultado.favorConductor;
    final enContra = _resultadoCrudo == DisputaResultado.favorCliente;
    final icon = aFavor ? Icons.check_rounded : (enContra ? Icons.close_rounded : Icons.info_outline_rounded);
    final gradientColors = aFavor
        ? const [ColoresApp.verdeOscuro, ColoresApp.verde]
        : enContra
            ? const [ColoresApp.rojo, ColoresApp.rojo]
            : const [ColoresApp.azul, ColoresApp.azul];

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
              fontSize: 22,
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
