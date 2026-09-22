import 'environment.dart';

/// Convierte la ruta de un archivo devuelta por la API en una URL cargable.
///
/// - URLs absolutas (`http(s)://`) se devuelven tal cual.
/// - Rutas relativas (`/storage/uploads/x.png?exp=..&sig=..`) se prefijan con
///   el backend conservando la query: los documentos privados (cédula,
///   licencia, comprobantes, soportes de disputa) llegan firmados y la firma
///   caduca en 1 hora, así que no se deben guardar en caché más tiempo.
/// - Un nombre suelto (`x.png`) se resuelve dentro de `/storage/uploads/`.
///
/// Devuelve `null` si no hay ruta, para que la UI muestre su placeholder.
String? resolveMediaUrl(String? path) {
  if (path == null) return null;
  final p = path.trim();
  if (p.isEmpty) return null;
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  final base = Environment.baseUrl.endsWith('/')
      ? Environment.baseUrl.substring(0, Environment.baseUrl.length - 1)
      : Environment.baseUrl;
  if (p.startsWith('/')) return '$base$p';
  return '$base/storage/uploads/$p';
}
