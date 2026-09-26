import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/core/formato_dinero.dart';

/// Formato único del dinero: "$90.000" (punto de miles, sin decimales ni
/// espacio), como lo lee un usuario colombiano.
void main() {
  test('formatearPesos: miles con punto, sin decimales ni espacio', () {
    expect(formatearPesos(90000), '\$90.000');
    expect(formatearPesos(1500000), '\$1.500.000');
    expect(formatearPesos(999), '\$999');
    expect(formatearPesos(0), '\$0');
    expect(formatearPesos(17000.0), '\$17.000');
    expect(formatearPesos(20000.49), '\$20.000');
    expect(formatearPesos(20000.5), '\$20.001');
    expect(formatearPesos(-1500.4), '-\$1.500');
  });

  test('formatearPesos: null devuelve el texto de respaldo', () {
    expect(formatearPesos(null), '-');
    expect(formatearPesos(null, siNulo: '—'), '—');
    expect(formatearPesos(double.nan, siNulo: '--'), '--');
  });

  test('formatearPesosDe acepta texto decimal del backend', () {
    expect(formatearPesosDe('20000.00'), '\$20.000');
    expect(formatearPesosDe(45000), '\$45.000');
    expect(formatearPesosDe('abc'), '-');
    expect(formatearPesosDe(null, siNulo: '\$0'), '\$0');
  });

  test('formatearPesosSiPositivo: solo montos mayores que cero', () {
    expect(formatearPesosSiPositivo(15000), '\$15.000');
    expect(formatearPesosSiPositivo('12000.50'), '\$12.001');
    expect(formatearPesosSiPositivo(0), isNull);
    expect(formatearPesosSiPositivo('0.00'), isNull);
    expect(formatearPesosSiPositivo(-5), isNull);
    expect(formatearPesosSiPositivo(null), isNull);
  });

  test('montoDe: num, texto decimal o null', () {
    expect(montoDe(12), 12);
    expect(montoDe('12.5'), 12.5);
    expect(montoDe(' 300 '), 300);
    expect(montoDe(''), isNull);
    expect(montoDe(null), isNull);
  });
}
