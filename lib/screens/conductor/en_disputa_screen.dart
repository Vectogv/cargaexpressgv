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
                  fontSize: 24,
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
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onEnviarMiVersion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.azul,
                    disabledBackgroundColor: ColoresApp.divisor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Enviar mi versión',
                    style: TextStyle(
                      fontSize: 16,
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
                onPressed: onVerDetalles,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled) ? ColoresApp.divisor : ColoresApp.azul,
                  ),
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.disabled) ? ColoresApp.divisor : ColoresApp.azul,
                      width: 1.5,
                    ),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                  child: const Text(
                    'Ver detalles de la disputa',
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
        color: Color(0xFFD32F2F),
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
