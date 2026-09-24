import 'package:flutter_test/flutter_test.dart';

import 'package:cargaexpress/models/user.dart';

/// `User` (lib/models/user.dart) es el modelo real que usa `Trip.conductor`
/// (distinto de `UserModel`, cubierto en user_model_test.dart). El rediseño
/// del rastreo (commit cdd80c4) le agregó `placa`, `tipoVehiculo` y
/// `totalViajes`, que el backend a veces envía como texto.
void main() {
  group('User.fromJson/toJson: placa, tipoVehiculo, totalViajes', () {
    test('van y vuelven igual con tipos correctos', () {
      final json = {
        '_id': 'c1',
        'nombre': 'Carlos',
        'placa': 'ABC123',
        'tipoVehiculo': 'camion',
        'totalViajes': 12,
      };
      final user = User.fromJson(json);
      expect(user.placa, 'ABC123');
      expect(user.tipoVehiculo, 'camion');
      expect(user.totalViajes, 12);

      final out = user.toJson();
      expect(out['placa'], 'ABC123');
      expect(out['tipoVehiculo'], 'camion');
      expect(out['totalViajes'], 12);
    });

    test('totalViajes como texto (el backend a veces lo envía así) se convierte a num', () {
      expect(User.fromJson({'_id': 'c1', 'totalViajes': '25'}).totalViajes, 25);
      expect(User.fromJson({'_id': 'c1', 'totalViajes': '3.0'}).totalViajes, 3.0);
    });

    test('totalViajes con texto no numérico no revienta: queda null', () {
      expect(User.fromJson({'_id': 'c1', 'totalViajes': 'no-numero'}).totalViajes, isNull);
    });

    test('sin placa, tipoVehiculo ni totalViajes quedan en null', () {
      final user = User.fromJson({'_id': 'c1'});
      expect(user.placa, isNull);
      expect(user.tipoVehiculo, isNull);
      expect(user.totalViajes, isNull);
    });

    test('placa y tipoVehiculo numéricos se normalizan a texto', () {
      final user = User.fromJson({'_id': 'c1', 'placa': 123, 'tipoVehiculo': 456});
      expect(user.placa, '123');
      expect(user.tipoVehiculo, '456');
    });
  });
}
