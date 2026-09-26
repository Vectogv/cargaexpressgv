import 'package:flutter/material.dart';

/// Piezas de interfaz compartidas por las pantallas rediseñadas
/// (conductor_en_la_zona_screen, llegada_al_destino_screen,
/// cuenta_no_activa_dialog y el inicio del conductor): misma paleta, mismos
/// radios y sombras, para no repetir el mismo `Container` en cada pantalla.
class ColoresApp {
  ColoresApp._();

  static const Color azul = Color(0xFF2563EB);
  static const Color azulOscuro = Color(0xFF1A3C6E);
  static const Color azulMarino = Color(0xFF1E3A8A);
  static const Color verde = Color(0xFF16A34A);
  static const Color rojo = Color(0xFFDC2626);
  static const Color naranja = Color(0xFFEA580C);
  static const Color ambar = Color(0xFFF59E0B);
  static const Color textoOscuro = Color(0xFF111827);
  static const Color textoSecundario = Color(0xFF6B7280);
  static const Color fondo = Color(0xFFF5F7FA);
  static const Color borde = Color(0xFFE5E7EB);
}

/// Tarjeta blanca con esquinas redondeadas y sombra suave.
class TarjetaBlanca extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final Color? colorBorde;

  const TarjetaBlanca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radio = 16,
    this.colorBorde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radio),
        border: colorBorde != null ? Border.all(color: colorBorde!) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

/// Botón principal (relleno) de 52 px con icono opcional y estado de carga.
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool cargando;
  final Color color;
  final double alto;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.color = ColoresApp.azul,
    this.alto = 52,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: color.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
    final habilitado = cargando ? null : onPressed;
    final Widget contenido = cargando
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(texto, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis);
    return SizedBox(
      width: double.infinity,
      height: alto,
      child: icono == null || cargando
          ? FilledButton(onPressed: habilitado, style: estilo, child: contenido)
          : FilledButton.icon(onPressed: habilitado, style: estilo, icon: Icon(icono, size: 22), label: contenido),
    );
  }
}

/// Botón secundario (contorno) del mismo tamaño que [BotonPrincipal].
class BotonSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool cargando;
  final Color color;
  final double alto;

  const BotonSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.color = ColoresApp.azul,
    this.alto = 52,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
    final habilitado = cargando ? null : onPressed;
    final Widget contenido = cargando
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
        : Text(texto, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis);
    return SizedBox(
      width: double.infinity,
      height: alto,
      child: icono == null || cargando
          ? OutlinedButton(onPressed: habilitado, style: estilo, child: contenido)
          : OutlinedButton.icon(onPressed: habilitado, style: estilo, icon: Icon(icono, size: 20), label: contenido),
    );
  }
}

/// Encabezado de estado: degradado con un icono redondo, título y detalle
/// ("¡Tu conductor llegó!", "Conduce al punto de recogida"...).
class EncabezadoEstado extends StatelessWidget {
  final String titulo;
  final String detalle;
  final IconData icono;
  final List<Color> colores;

  const EncabezadoEstado({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.icono,
    this.colores = const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
  });

  @override
  Widget build(BuildContext context) {
    return FondoDegradado(
      colores: colores,
      radio: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              child: Icon(icono, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(detalle, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra fija de acciones para `Scaffold.bottomNavigationBar`: fondo blanco,
/// sombra hacia arriba y respeto del área segura inferior.
class BarraInferiorFija extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BarraInferiorFija({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Fondo con degradado sobre un color sólido de respaldo. Si el degradado no
/// llega a pintarse (p. ej. emuladores sin aceleración gráfica, donde el
/// encabezado azul de la bienvenida salía blanco), queda el color sólido.
class FondoDegradado extends StatelessWidget {
  final List<Color> colores;
  final BorderRadiusGeometry? radio;
  final AlignmentGeometry inicio;
  final AlignmentGeometry fin;
  final Widget child;

  const FondoDegradado({
    super.key,
    required this.colores,
    required this.child,
    this.radio,
    this.inicio = Alignment.topLeft,
    this.fin = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('fondo_degradado_solido'),
      decoration: BoxDecoration(color: colores.first, borderRadius: radio),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colores, begin: inicio, end: fin),
          borderRadius: radio,
        ),
        child: child,
      ),
    );
  }
}
