import 'package:flutter/material.dart';

import '../services/api/http_client.dart' show ApiException;

/// Mensaje legible de un error de API/red para mostrar al usuario.
String mensajeDeError(Object e) {
  if (e is ApiException) return e.message;
  final s = e.toString().replaceFirst('Exception: ', '').trim();
  return s.isEmpty ? 'Ocurrió un error inesperado.' : s;
}

/// Estado de error de una carga con botón para reintentar.
class ErrorCarga extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final VoidCallback onReintentar;

  const ErrorCarga({
    super.key,
    required this.titulo,
    required this.onReintentar,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
            ),
            if (detalle != null && detalle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
