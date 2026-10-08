import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Guarda [bytes] en la carpeta pública Descargas de Android: en 11+ se crea
/// sin permiso, en 10 lo permite `requestLegacyExternalStorage` y en 9 o menos
/// pide el permiso.
Future<void> guardarEnDescargas(String nombre, List<int> bytes) async {
  final file = File('/storage/emulated/0/Download/$nombre');
  try {
    await file.writeAsBytes(bytes, flush: true);
  } on FileSystemException {
    if (!await Permission.storage.request().isGranted) {
      throw Exception('Permite el acceso al almacenamiento para guardar el PDF en Descargas');
    }
    await file.writeAsBytes(bytes, flush: true);
  }
}
