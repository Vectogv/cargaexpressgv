import 'package:flutter/material.dart';

import '../auth_estilos.dart';

/// Armazón de los asistentes de registro (cliente y conductor): barra con
/// marca, "atrás" y progreso, una vista por paso con transición, y el botón
/// principal abajo. El estado (paso actual, validación, envío) lo lleva cada
/// pantalla; aquí solo se pinta.
class AsistenteRegistro extends StatelessWidget {
  /// Identifica la vista para la transición (cambia con cada paso).
  final String claveVista;
  final Widget child;

  /// Mientras se lee el borrador o el perfil: solo un spinner.
  final bool cargando;

  /// Sin flecha de volver (enviando, terminado, borrador pendiente...).
  final bool sinVolver;

  /// Si el gesto de volver puede cerrar la pantalla (primer paso).
  final bool canPop;
  final VoidCallback onAtras;

  /// 0..1 bajo la barra; null la oculta.
  final double? progreso;

  /// Texto del botón principal; null lo oculta.
  final String? textoBoton;
  final String textoBotonCargando;
  final bool botonCargando;
  final VoidCallback? onContinuar;

  const AsistenteRegistro({
    super.key,
    required this.claveVista,
    required this.child,
    required this.onAtras,
    this.cargando = false,
    this.sinVolver = false,
    this.canPop = false,
    this.progreso,
    this.textoBoton,
    this.textoBotonCargando = '',
    this.botonCargando = false,
    this.onContinuar,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho && !sinVolver) onAtras();
      },
      child: Scaffold(
        backgroundColor: AuthColores.fondo,
        appBar: AppBar(
          backgroundColor: AuthColores.fondo,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: sinVolver ? null : BackButton(key: const Key('btn_atras'), color: AuthColores.texto, onPressed: onAtras),
          title: const MarcaCargaExpress(tamano: 17),
          centerTitle: true,
          bottom: progreso == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 4,
                    backgroundColor: AuthColores.borde,
                    color: AuthColores.primario,
                  ),
                ),
        ),
        body: cargando
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                                  child: child,
                                ),
                              ),
                              layoutBuilder: (actual, previos) => Stack(
                                alignment: Alignment.topCenter,
                                children: [...previos, if (actual != null) actual],
                              ),
                              child: KeyedSubtree(key: ValueKey(claveVista), child: child),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (textoBoton != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: BotonPrincipalAuth(
                              key: const Key('btn_continuar'),
                              texto: textoBoton!,
                              textoCargando: textoBotonCargando,
                              cargando: botonCargando,
                              onPressed: onContinuar,
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

/// Título y detalle de un paso.
Widget tituloPaso(String titulo, String detalle) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AuthColores.texto, letterSpacing: -0.5, height: 1.15)),
        const SizedBox(height: 6),
        Text(detalle, style: const TextStyle(fontSize: 15, color: AuthColores.gris, height: 1.35)),
        const SizedBox(height: 22),
      ],
    );

/// Paso con título y una tarjeta con [hijos].
Widget pantallaPaso(String titulo, String detalle, List<Widget> hijos) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tituloPaso(titulo, detalle),
        TarjetaAuth(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos)),
      ],
    );
