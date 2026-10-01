import 'package:cargaexpress/services/banner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('banner con solo imagen (sin texto) es visible', () {
    final b = BannerPlataforma.fromJson({'activo': true, 'imagenUrl': '/storage/uploads/banner-1.png', 'texto': null, 'link': null});
    expect(b.visible, isTrue);
    expect(b.imagenUrl, '/storage/uploads/banner-1.png');
  });

  test('banner inactivo o vacío no se muestra', () {
    expect(BannerPlataforma.fromJson({'activo': false, 'imagenUrl': '/x.png'}).visible, isFalse);
    expect(BannerPlataforma.fromJson({'activo': true, 'texto': '', 'imagenUrl': null}).visible, isFalse);
  });
}
