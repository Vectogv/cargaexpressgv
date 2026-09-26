/// Formato único del dinero en la app: pesos colombianos como los lee el
/// usuario, "$90.000" (punto de miles, sin decimales ni espacio). Antes cada
/// pantalla tenía su copia y varias mostraban "$90000" o "$ 90.000".
library;

/// `90000` → `$90.000`; `-1500.4` → `-$1.500`. Con `null` devuelve [siNulo].
String formatearPesos(num? valor, {String siNulo = '-'}) {
  if (valor == null || valor.isNaN || valor.isInfinite) return siNulo;
  final entero = valor.round();
  final digitos = entero.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${entero < 0 ? '-' : ''}\$$digitos';
}

/// Como [formatearPesos] pero acepta lo que mande el backend: número o texto
/// decimal (`"20000.00"`). Si no es un número devuelve [siNulo].
String formatearPesosDe(dynamic valor, {String siNulo = '-'}) => formatearPesos(montoDe(valor), siNulo: siNulo);

/// `$12.000` solo si hay un monto positivo; si no, `null` (deudas,
/// reembolsos y avisos que no deben mostrarse con "$0").
String? formatearPesosSiPositivo(dynamic valor) {
  final n = montoDe(valor);
  if (n == null || n <= 0) return null;
  return formatearPesos(n);
}

/// Número de un campo del backend: `num`, texto decimal o `null`.
num? montoDe(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor;
  return num.tryParse(valor.toString().trim());
}
