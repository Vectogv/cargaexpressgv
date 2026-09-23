import 'package:flutter/material.dart';

/// Paleta y piezas visuales compartidas por bienvenida, login y registro
/// (mismo lenguaje que el inicio del cliente y "Buscando conductor").
class AuthColores {
  static const primario = Color(0xFF2563EB);
  static const primarioOscuro = Color(0xFF1E3A8A);
  static const texto = Color(0xFF1A1A2E);
  static const gris = Color(0xFF6B7280);
  static const borde = Color(0xFFE5E7EB);
  static const fondo = Color(0xFFF5F7FA);
  static const campo = Color(0xFFF9FAFB);
  static const error = Color(0xFFB91C1C);
}

/// Marca: cuadro azul con el camión + "CargaExpress".
class MarcaCargaExpress extends StatelessWidget {
  final bool sobreOscuro;
  final double tamano;
  const MarcaCargaExpress({super.key, this.sobreOscuro = false, this.tamano = 20});

  @override
  Widget build(BuildContext context) {
    final colorTexto = sobreOscuro ? Colors.white : AuthColores.texto;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tamano * 1.8,
          height: tamano * 1.8,
          decoration: BoxDecoration(
            color: sobreOscuro ? Colors.white.withValues(alpha: 0.18) : AuthColores.primario,
            borderRadius: BorderRadius.circular(tamano * 0.5),
          ),
          child: Icon(Icons.local_shipping_rounded, color: Colors.white, size: tamano),
        ),
        SizedBox(width: tamano * 0.5),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Carga', style: TextStyle(fontWeight: FontWeight.w500, color: colorTexto)),
              TextSpan(text: 'Express', style: TextStyle(fontWeight: FontWeight.w800, color: colorTexto)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: tamano, letterSpacing: -0.3),
          ),
        ),
      ],
    );
  }
}

/// Decoración de los campos de texto de autenticación.
InputDecoration decoracionCampoAuth({
  required String label,
  required IconData icono,
  String? ayuda,
  Widget? sufijo,
}) {
  OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: ancho),
      );
  return InputDecoration(
    labelText: label,
    helperText: ayuda,
    helperMaxLines: 2,
    errorMaxLines: 3,
    prefixIcon: Icon(icono, size: 20),
    suffixIcon: sufijo,
    filled: true,
    fillColor: AuthColores.campo,
    counterText: '',
    border: borde(AuthColores.borde),
    enabledBorder: borde(AuthColores.borde),
    focusedBorder: borde(AuthColores.primario, 1.6),
    errorBorder: borde(AuthColores.error),
    focusedErrorBorder: borde(AuthColores.error, 1.6),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  );
}

/// Tarjeta blanca con borde suave.
class TarjetaAuth extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const TarjetaAuth({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthColores.borde),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// Aviso de error (respuesta del backend o validación general).
class AvisoErrorAuth extends StatelessWidget {
  final String mensaje;
  const AvisoErrorAuth({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('aviso_error_auth'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 20, color: AuthColores.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF7F1D1D), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón principal con estado de carga.
class BotonPrincipalAuth extends StatelessWidget {
  final String texto;
  final String textoCargando;
  final bool cargando;
  final VoidCallback? onPressed;
  const BotonPrincipalAuth({
    super.key,
    required this.texto,
    required this.textoCargando,
    required this.cargando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: cargando ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AuthColores.primario,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AuthColores.primario.withValues(alpha: 0.7),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: cargando
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(textoCargando, overflow: TextOverflow.ellipsis)),
              ],
            )
          : Text(texto, textAlign: TextAlign.center),
    );
  }
}

/// Texto + enlace para cambiar entre login y registro.
class EnlaceAuth extends StatelessWidget {
  final String pregunta;
  final String accion;
  final VoidCallback onTap;
  final Key? botonKey;
  const EnlaceAuth({super.key, required this.pregunta, required this.accion, required this.onTap, this.botonKey});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(pregunta, style: const TextStyle(fontSize: 14, color: AuthColores.gris)),
        TextButton(
          key: botonKey,
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: AuthColores.primario),
          child: Text(accion, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
