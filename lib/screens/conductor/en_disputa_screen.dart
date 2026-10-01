import 'package:flutter/material.dart';
import '../shared/ui_compartida.dart';

class EnDisputaScreen extends StatelessWidget {
  final VoidCallback? onEnviarMiVersion;
  final VoidCallback? onVerDetalles;

  const EnDisputaScreen({
    super.key,
    this.onEnviarMiVersion,
    this.onVerDetalles,
  });


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 72),
              _DisputeIcon(),
              const SizedBox(height: 24),
              const Text(
                'En disputa',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ColoresApp.textoOscuro,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nuestro equipo está revisando\nel caso.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: ColoresApp.textoSecundario,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Por favor proporciona tu versión\ny evidencia.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: ColoresApp.textoSecundario,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 40),
              BotonPrincipal(texto: 'Enviar mi versión', onPressed: onEnviarMiVersion),
              const SizedBox(height: 14),
              BotonSecundario(texto: 'Ver detalles de la disputa', onPressed: onVerDetalles),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisputeIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        color: ColoresApp.rojo,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.gavel_rounded,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }
}
