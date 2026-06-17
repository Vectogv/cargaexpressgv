import 'package:flutter_test/flutter_test.dart';
import 'package:cargaexpress/models/user_model.dart';

void main() {
  group('UserModel', () {
    const testId = 'user123';
    const testNombre = 'Juan';
    const testEmail = 'juan@test.com';
    const testRol = 'cliente';

    final completeJson = {
      '_id': testId,
      'nombre': testNombre,
      'apellido': 'Pérez',
      'email': testEmail,
      'rol': testRol,
      'telefono': '5512345678',
      'calificacion': 4.5,
    };

    group('fromJson', () {
      test('creates model from complete JSON', () {
        final model = UserModel.fromJson(completeJson);
        expect(model.id, testId);
        expect(model.nombre, testNombre);
        expect(model.email, testEmail);
        expect(model.rol, testRol);
        expect(model.calificacion, 4.5);
      });

      test('handles alternate id key "id"', () {
        final json = {'id': 'altId', 'nombre': 'Test'};
        final model = UserModel.fromJson(json);
        expect(model.id, 'altId');
      });

      test('prefers _id over id', () {
        final json = {'_id': 'primary', 'id': 'secondary', 'nombre': 'Test'};
        final model = UserModel.fromJson(json);
        expect(model.id, 'primary');
      });

      test('handles null fields', () {
        final json = {'_id': testId};
        final model = UserModel.fromJson(json);
        expect(model.id, testId);
        expect(model.nombre, isNull);
        expect(model.email, isNull);
        expect(model.calificacion, isNull);
      });

      test('parses calificacion from int or string', () {
        final jsonStr = {'_id': 'x', 'calificacion': '4.5'};
        expect(UserModel.fromJson(jsonStr).calificacion, 4.5);

        final jsonInt = {'_id': 'x', 'calificacion': 5};
        expect(UserModel.fromJson(jsonInt).calificacion, 5.0);
      });
    });

    group('toJson', () {
      test('includes _id only when all fields present', () {
        final model = UserModel.fromJson(completeJson);
        final json = model.toJson();
        expect(json['_id'], testId);
        expect(json['nombre'], testNombre);
        expect(json['calificacion'], 4.5);
      });

      test('omits null fields', () {
        final model = UserModel(id: 'x');
        final json = model.toJson();
        expect(json.keys, ['_id']);
      });
    });

    group('copyWith', () {
      test('overrides specified fields', () {
        final a = UserModel(id: '1', nombre: 'A');
        final b = a.copyWith(nombre: 'B');
        expect(b.id, '1');
        expect(b.nombre, 'B');
      });
    });
  });
}
