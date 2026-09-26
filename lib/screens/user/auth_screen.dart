import 'package:flutter/material.dart';

import '../shared/ui_compartida.dart' show FondoDegradado;
import 'auth_estilos.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Bienvenida: marca, propuesta de valor y acceso a login / registro.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Cabecera(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        children: [
                          _Beneficio(
                            icono: Icons.sell_outlined,
                            titulo: 'Tú propones el precio',
                            texto: 'Publica tu envío y recibe ofertas de conductores.',
                          ),
                          SizedBox(height: 14),
                          _Beneficio(
                            icono: Icons.near_me_outlined,
                            titulo: 'Conductores cerca de ti',
                            texto: 'Motos, camionetas y camiones listos para recoger.',
                          ),
                          SizedBox(height: 14),
                          _Beneficio(
                            icono: Icons.verified_user_outlined,
                            titulo: 'Seguimiento en vivo',
                            texto: 'Mira dónde va tu carga y confirma la entrega.',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BotonPrincipalAuth(
                            key: const Key('btn_ir_login'),
                            texto: 'Iniciar sesión',
                            textoCargando: '',
                            cargando: false,
                            onPressed: () => _abrir(context, const LoginScreen()),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('btn_ir_registro'),
                            onPressed: () => _abrir(context, const RegisterScreen()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AuthColores.primario,
                              minimumSize: const Size.fromHeight(52),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              side: const BorderSide(color: AuthColores.primario, width: 1.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Crear cuenta', textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    // Color sólido debajo del degradado: en algunos emuladores el degradado
    // no se pintaba y la cabecera salía blanca con texto blanco encima.
    return FondoDegradado(
      key: const Key('cabecera_bienvenida'),
      colores: const [AuthColores.primario, AuthColores.primarioOscuro],
      radio: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MarcaCargaExpress(sobreOscuro: true),
              const SizedBox(height: 20),
              const Center(child: _Ilustracion()),
              const SizedBox(height: 20),
              const Text(
                'Envía tu carga sin complicaciones',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Conectamos tu envío con conductores de confianza, al precio que acuerdes.',
                style: TextStyle(fontSize: 15, color: Color(0xE6FFFFFF), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ilustración hecha con formas e iconos de Material: ruta de origen a
/// destino con el camión en medio.
class _Ilustracion extends StatelessWidget {
  const _Ilustracion();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 250,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
            ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
            ),
            // Ruta punteada.
            Positioned(
              left: 30,
              right: 30,
              bottom: 22,
              child: Row(
                children: List.generate(
                  11,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const _Pin(left: 4, bottom: 8, icono: Icons.inventory_2_rounded, color: Color(0xFFF59E0B)),
            const _Pin(right: 4, bottom: 8, icono: Icons.location_on_rounded, color: Color(0xFF16A34A)),
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
              ),
              child: const Icon(Icons.local_shipping_rounded, size: 36, color: AuthColores.primario),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final double? left;
  final double? right;
  final double bottom;
  final IconData icono;
  final Color color;
  const _Pin({this.left, this.right, required this.bottom, required this.icono, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Icon(icono, size: 20, color: color),
      ),
    );
  }
}

class _Beneficio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Beneficio({required this.icono, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(12)),
          child: Icon(icono, size: 21, color: AuthColores.primario),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AuthColores.texto)),
              const SizedBox(height: 2),
              Text(texto, style: const TextStyle(fontSize: 13.5, color: AuthColores.gris, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
