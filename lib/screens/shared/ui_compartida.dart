import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Piezas de interfaz compartidas por las pantallas rediseñadas
/// (conductor_en_la_zona_screen, llegada_al_destino_screen,
/// cuenta_no_activa_dialog y el inicio del conductor): misma paleta, mismos
/// radios y sombras, para no repetir el mismo `Container` en cada pantalla.
class ColoresApp {
  ColoresApp._();

  static const Color azul = Color(0xFF1F5FD6);
  static const Color azulTenue = Color(0xFFEAF1FC);
  static const Color azulOscuro = Color(0xFF1A3C6E);
  static const Color azulMarino = Color(0xFF1E3A8A);
  static const Color verde = Color(0xFF16A34A);
  static const Color rojo = Color(0xFFDC2626);
  /// Solo para "Cerrar sesión".
  static const Color rojoSesion = Color(0xFFB42318);
  static const Color naranja = Color(0xFFE07A1F);
  static const Color naranjaTexto = Color(0xFFA8560F);
  static const Color naranjaFondo = Color(0xFFFFF4EA);
  static const Color naranjaBorde = Color(0xFFF6D3B3);
  static const Color naranjaAviso = Color(0xFF7A3E0A);
  static const Color ambar = Color(0xFFF59E0B);
  static const Color estrella = Color(0xFFE0A21F);
  static const Color placaFondo = Color(0xFFF4C430);
  static const Color placaTexto = Color(0xFF111111);
  static const Color textoOscuro = Color(0xFF0F1B2D);
  static const Color textoSecundario = Color(0xFF5B6576);
  static const Color etiquetaCampo = Color(0xFF3A4556);
  static const Color chevron = Color(0xFF8A93A3);
  static const Color fondo = Color(0xFFF4F6F8);
  static const Color fondoPin = Color(0xFFFAFBFC);
  static const Color borde = Color(0xFFE3E6EB);
  static const Color divisor = Color(0xFFEEF0F3);
  static const Color bordeCampo = Color(0xFFD5DAE1);
  // Tokens del prototipo "Ciudad Blanca" (conductor) que no existían arriba.
  static const Color gris = Color(0xFF475467);
  static const Color grisClaro = Color(0xFF667085);
  static const Color verdeOscuro = Color(0xFF12805C);
  static const Color verdeFondo = Color(0xFFE7F6EF);
  static const Color rojoFondo = Color(0xFFFDECEA);
  static const Color fondoItem = Color(0xFFF7F9FC);
  static const Color campoDeshabilitado = Color(0xFFF2F4F7);
  static const Color manija = Color(0xFFD0D5DD);
  /// Velo de las hojas y diálogos: rgba(16,24,40,.42).
  static const Color velo = Color(0x6B101828);
}

/// Cifras alineadas (`font-variant-numeric: tabular-nums`).
const List<FontFeature> cifrasTabulares = [FontFeature.tabularFigures()];

const String _fuente = 'InstrumentSans';

/// Escala del prototipo: 22/700, 17/600, 15/400, 13/400 y 12/600.
TextStyle _t(double tamano, FontWeight peso, double alto, {Color color = ColoresApp.textoOscuro, double espaciado = 0}) =>
    TextStyle(
      fontFamily: _fuente,
      fontSize: tamano,
      fontWeight: peso,
      height: alto / tamano,
      color: color,
      letterSpacing: espaciado,
      fontFeatures: cifrasTabulares,
    );

/// Tema único de la app: escala de letra, diálogos de radio 20, hojas con
/// manija, campos de 52 px con radio 14 y transición suave entre pantallas.
ThemeData temaApp() {
  final radio14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  OutlineInputBorder borde(Color color, [double grosor = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: grosor));
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
    useMaterial3: true,
    fontFamily: _fuente,
    textTheme: TextTheme(
      headlineSmall: _t(22, FontWeight.w700, 28, espaciado: -0.2),
      titleMedium: _t(17, FontWeight.w600, 24),
      bodyLarge: _t(15, FontWeight.w400, 22),
      bodyMedium: _t(13, FontWeight.w400, 18),
      bodySmall: _t(12, FontWeight.w400, 16, color: ColoresApp.grisClaro),
      labelLarge: _t(15, FontWeight.w600, 22),
      labelSmall: _t(12, FontWeight.w600, 16, color: ColoresApp.grisClaro, espaciado: 0.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: _t(17, FontWeight.w600, 24),
      contentTextStyle: _t(13, FontWeight.w400, 18, color: ColoresApp.gris),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: ColoresApp.velo,
      dragHandleColor: ColoresApp.manija,
      dragHandleSize: Size(40, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? ColoresApp.campoDeshabilitado : Colors.white,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: borde(ColoresApp.borde),
      enabledBorder: borde(ColoresApp.borde),
      disabledBorder: borde(ColoresApp.borde),
      focusedBorder: borde(ColoresApp.azul, 2),
      errorBorder: borde(ColoresApp.rojo),
      focusedErrorBorder: borde(ColoresApp.rojo, 2),
      hintStyle: _t(15, FontWeight.w400, 22, color: ColoresApp.grisClaro),
      labelStyle: _t(13, FontWeight.w600, 18, color: ColoresApp.etiquetaCampo),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: radio14, textStyle: _t(15, FontWeight.w600, 22, color: Colors.white)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: radio14, textStyle: _t(15, FontWeight.w600, 22)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: radio14, textStyle: _t(15, FontWeight.w600, 22)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ColoresApp.azul, textStyle: _t(15, FontWeight.w600, 22)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _TransicionSuave(),
      TargetPlatform.iOS: _TransicionSuave(),
    }),
  );
}

/// Entrada de pantalla: se desvanece y sube apenas (10 px), como el
/// prototipo; la pantalla de atrás no se mueve.
class _TransicionSuave extends PageTransitionsBuilder {
  const _TransicionSuave();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curva = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curva),
        child: child,
      ),
    );
  }
}

/// Tarjeta blanca con esquinas redondeadas y borde de 1 px, sin sombra.
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
        border: Border.all(color: colorBorde ?? ColoresApp.borde),
      ),
      child: child,
    );
  }
}

/// Texto de los botones con la letra del tema (ver [BotonPrincipal]).
TextStyle _estiloTextoBoton(BuildContext context, double tamano) =>
    (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
        .copyWith(fontSize: tamano, fontWeight: FontWeight.w600, letterSpacing: 0);

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
      // Material pone 24 dp a cada lado: en filas de 3 botones (360 dp) el
      // texto salía cortado ("Sem…"). Siempre ocupan todo el ancho, así que
      // el padding solo cuenta cuando el texto está justo.
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.45),
      // Un TextStyle suelto reemplaza el del tema entero (Material lo usa tal
      // cual) y el botón salía en Roboto, no en la letra de la app.
      textStyle: _estiloTextoBoton(context, 15),
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
  /// Borde distinto del texto (p. ej. gris claro con texto oscuro).
  final Color? colorBorde;
  final double alto;

  const BotonSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.color = ColoresApp.azul,
    this.colorBorde,
    this.alto = 52,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = OutlinedButton.styleFrom(
      foregroundColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: colorBorde ?? color, width: colorBorde == null ? 1.5 : 1),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: _estiloTextoBoton(context, 15),
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
///
/// Sube con el teclado. `Scaffold` solo encoge el `body` cuando aparece el
/// teclado; el `bottomNavigationBar` se queda pegado al borde de la pantalla
/// y el teclado lo tapa (así se perdía el botón de enviar del chat del
/// ticket). Aquí se suma `viewInsets.bottom` para que la barra quede justo
/// encima del teclado; el cuerpo se encoge lo mismo, sin contarlo dos veces.
/// Con [subeConTeclado] en `false` se deja el comportamiento nativo.
class BarraInferiorFija extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool subeConTeclado;

  const BarraInferiorFija({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.subeConTeclado = true,
  });

  @override
  Widget build(BuildContext context) {
    final teclado = subeConTeclado ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: teclado),
        child: SafeArea(
          top: false,
          child: Padding(padding: padding, child: child),
        ),
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


/// Diálogo del prototipo: icono en caja, título 17, cuerpo 13 y uno o dos
/// botones de 52 px uno debajo del otro. Es un [AlertDialog] por dentro para
/// que `find.byType(AlertDialog)` y `scrollable` sigan funcionando.
class DialogoApp extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final String? cuerpo;
  final Widget? contenido;
  final String? textoPrincipal;
  final VoidCallback? onPrincipal;
  final Color colorPrincipal;
  final bool cargando;
  final String? textoSecundario;
  final VoidCallback? onSecundario;
  final bool desplazable;

  const DialogoApp({
    super.key,
    required this.icono,
    required this.titulo,
    this.textoPrincipal,
    this.onPrincipal,
    this.colorIcono = ColoresApp.azul,
    this.cuerpo,
    this.contenido,
    this.colorPrincipal = ColoresApp.azul,
    this.cargando = false,
    this.textoSecundario,
    this.onSecundario,
    this.desplazable = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: desplazable,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            CajaIcono(icono: icono, color: colorIcono),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: _t(17, FontWeight.w600, 24))),
          ]),
          if (cuerpo != null) ...[
            const SizedBox(height: 10),
            Text(cuerpo!, style: _t(13, FontWeight.w400, 18, color: ColoresApp.gris)),
          ],
          if (contenido != null) ...[const SizedBox(height: 14), contenido!],
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (textoPrincipal != null)
              BotonPrincipal(texto: textoPrincipal!, onPressed: onPrincipal, color: colorPrincipal, cargando: cargando),
            if (textoSecundario != null) ...[
              if (textoPrincipal != null) const SizedBox(height: 8),
              BotonSecundario(
                texto: textoSecundario!,
                onPressed: cargando ? null : (onSecundario ?? () => Navigator.pop(context)),
                color: ColoresApp.textoOscuro,
                colorBorde: ColoresApp.borde,
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

/// Caja de 44 px con el icono tintado sobre su color al 10 %.
class CajaIcono extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double tamano;

  const CajaIcono({super.key, required this.icono, this.color = ColoresApp.azul, this.tamano = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(tamano * 0.32)),
      child: Icon(icono, color: color, size: tamano * 0.52),
    );
  }
}

/// Hoja inferior del prototipo: manija, esquinas de 24, sube con el teclado y
/// se desplaza si no cabe. [builder] recibe el contexto de la hoja.
Future<T?> mostrarHojaApp<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => HojaApp(child: builder(ctx)),
  );
}

class HojaApp extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HojaApp({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(padding: padding, child: child),
      ),
    );
  }
}

/// Título 17 + detalle 13 de una hoja o sección.
class TituloHoja extends StatelessWidget {
  final String titulo;
  final String? detalle;

  const TituloHoja({super.key, required this.titulo, this.detalle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: _t(17, FontWeight.w600, 24)),
      if (detalle != null) ...[const SizedBox(height: 2), Text(detalle!, style: _t(13, FontWeight.w400, 18, color: ColoresApp.gris))],
    ]);
  }
}

/// Chip de estado (Aprobado, En revisión, Falta...): fondo claro y texto del
/// mismo tono, 12/600.
class ChipEstado extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  const ChipEstado({super.key, required this.texto, required this.color, required this.fondo, this.icono});

  const ChipEstado.azul(this.texto, {super.key, this.icono}) : color = ColoresApp.azul, fondo = ColoresApp.azulTenue;
  const ChipEstado.verde(this.texto, {super.key, this.icono}) : color = ColoresApp.verdeOscuro, fondo = ColoresApp.verdeFondo;
  const ChipEstado.naranja(this.texto, {super.key, this.icono}) : color = ColoresApp.naranjaTexto, fondo = ColoresApp.naranjaFondo;
  const ChipEstado.rojo(this.texto, {super.key, this.icono}) : color = ColoresApp.rojo, fondo = ColoresApp.rojoFondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icono != null) ...[Icon(icono, size: 14, color: color), const SizedBox(width: 6)],
        Text(texto, style: _t(12, FontWeight.w600, 16, color: color)),
      ]),
    );
  }
}

/// Aviso suave (naranja por defecto): icono + texto 13 en caja de radio 14.
class CajaAviso extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final Color fondo;

  const CajaAviso({
    super.key,
    required this.texto,
    this.icono = Icons.info_outline_rounded,
    this.color = ColoresApp.naranjaAviso,
    this.fondo = ColoresApp.naranjaFondo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: _t(13, FontWeight.w400, 18, color: color))),
      ]),
    );
  }
}

/// Tarjeta-radio del prototipo (motivos de cancelación): fondo azul tenue y
/// borde de 2 px al elegirla, punto de 20 px.
class OpcionRadio extends StatelessWidget {
  final String texto;
  final bool elegida;
  final VoidCallback onTap;

  const OpcionRadio({super.key, required this.texto, required this.elegida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegida ? ColoresApp.azulTenue : ColoresApp.fondoItem,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: elegida ? ColoresApp.azul : ColoresApp.borde, width: elegida ? 2 : 1),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: elegida ? ColoresApp.azul : ColoresApp.chevron, width: elegida ? 6 : 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: _t(15, FontWeight.w400, 22))),
          ]),
        ),
      ),
    );
  }
}

/// PIN de 4 cajas (56×64, radio 14). La caja activa lleva borde azul de 2 px;
/// con [error] las cajas se ponen rojas y tiemblan. Por encima hay un
/// `TextField` transparente que recibe el teclado (y `enterText` en tests).
class CampoPin extends StatefulWidget {
  final int largo;
  final ValueChanged<String> onChanged;
  final bool error;
  final bool autofocus;
  final double alto;

  const CampoPin({super.key, required this.onChanged, this.largo = 4, this.error = false, this.autofocus = true, this.alto = 64});

  @override
  State<CampoPin> createState() => _CampoPinState();
}

class _CampoPinState extends State<CampoPin> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _foco = FocusNode();
  late final AnimationController _temblor = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late bool _error = widget.error;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() {}));
    if (_error) _temblor.forward(from: 0);
  }

  @override
  void didUpdateWidget(CampoPin viejo) {
    super.didUpdateWidget(viejo);
    if (widget.error && !viejo.error) {
      _error = true;
      _temblor.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _foco.dispose();
    _temblor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = _ctrl.text;
    final activa = texto.length < widget.largo ? texto.length : widget.largo - 1;
    return SizedBox(
      height: widget.alto,
      child: Stack(children: [
        AnimatedBuilder(
          animation: _temblor,
          builder: (_, child) {
            final t = _temblor.value;
            return Transform.translate(offset: Offset(sin(t * pi * 4) * 6 * (1 - t), 0), child: child);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.largo; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 56,
                  height: widget.alto,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _error
                          ? ColoresApp.rojo
                          : (i == activa && _foco.hasFocus ? ColoresApp.azul : ColoresApp.borde),
                      width: _error || (i == activa && _foco.hasFocus) ? 2 : 1,
                    ),
                  ),
                  child: Text(i < texto.length ? texto[i] : '', style: _t(22, FontWeight.w700, 28)),
                ),
              ],
            ],
          ),
        ),
        // Transparente: el usuario ve las cajas, el teclado escribe aquí.
        Positioned.fill(
          child: TextField(
            controller: _ctrl,
            focusNode: _foco,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.largo)],
            expands: true,
            maxLines: null,
            minLines: null,
            showCursor: false,
            enableInteractiveSelection: false,
            autocorrect: false,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              setState(() => _error = false);
              widget.onChanged(v);
            },
          ),
        ),
      ]),
    );
  }
}
