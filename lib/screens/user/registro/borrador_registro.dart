import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Borrador de un registro a medias, en SharedPreferences como JSON. Nunca
/// se guardan la contraseña ni el idToken de Google.
class BorradorRegistro {
  final String clave;
  const BorradorRegistro(this.clave);

  /// null si no hay borrador (o estaba corrupto: se borra).
  Future<Map<String, dynamic>?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(clave);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      await prefs.remove(clave);
      return null;
    }
  }

  Future<void> guardar(Map<String, dynamic> datos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(clave, jsonEncode(datos));
  }

  Future<void> borrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(clave);
  }
}
