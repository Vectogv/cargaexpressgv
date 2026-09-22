import 'package:flutter/material.dart';

import '../core/media.dart';

/// Iniciales seguras (no revienta con nombres vacíos o con espacios dobles).
String initialsOf(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Imagen de la API (ruta relativa o firmada `/storage/uploads/x.png?exp=..`)
/// resuelta con [resolveMediaUrl]. Si no hay ruta, falla la descarga o la
/// firma caducó muestra [placeholder] en vez del cuadro rojo de error.
/// Decodifica al tamaño mostrado (cacheWidth) para no gastar memoria con
/// fotos de 1600 px en miniaturas.
class MediaImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const MediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(path);
    final fallback = placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFE5E7EB),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF)),
        );
    Widget child;
    if (url == null) {
      child = fallback;
    } else {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final w = width;
      child = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: (w != null && w.isFinite) ? (w * dpr).round() : null,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, img, progress) {
          if (progress == null) return img;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        },
      );
    }
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

/// Avatar circular: foto de la API si existe y carga; si no, iniciales (o un
/// icono) sobre [backgroundColor]. Nunca muestra imágenes de terceros.
class MediaAvatar extends StatelessWidget {
  final String? path;
  final String? name;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final double? fontSize;
  final IconData icon;
  final BoxBorder? border;

  const MediaAvatar({
    super.key,
    required this.path,
    this.name,
    this.radius = 26,
    this.backgroundColor = const Color(0xFFD1FAE5),
    this.foregroundColor = const Color(0xFF065F46),
    this.fontSize,
    this.icon = Icons.person,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final hasName = name != null && name!.trim().isNotEmpty;
    final fallback = Center(
      child: hasName
          ? Text(
              initialsOf(name),
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontSize: fontSize ?? radius * 0.62,
              ),
            )
          : Icon(icon, color: foregroundColor, size: radius),
    );
    final url = resolveMediaUrl(path);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: backgroundColor, border: border),
      child: url == null
          ? fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * dpr).round(),
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
