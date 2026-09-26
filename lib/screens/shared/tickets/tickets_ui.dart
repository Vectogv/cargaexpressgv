import 'package:flutter/material.dart';

import '../../../models/ticket_soporte.dart';
import '../ui_compartida.dart';

/// Piezas comunes de las pantallas de tickets de soporte (lista, nuevo y
/// detalle): color e icono por estado/categoría, chip de estado, tiempos
/// relativos y resumen de un viaje.

Color colorEstadoTicket(String estado) {
  switch (estado) {
    case 'abierto':
      return ColoresApp.azul;
    case 'en_proceso':
      return ColoresApp.ambar;
    case 'resuelto':
      return ColoresApp.verde;
    case 'cerrado':
      return ColoresApp.textoSecundario;
    default:
      return ColoresApp.textoSecundario;
  }
}

IconData iconoCategoriaTicket(String categoria) {
  switch (categoria) {
    case 'pago':
      return Icons.payments_outlined;
    case 'viaje':
      return Icons.local_shipping_outlined;
    case 'cuenta':
      return Icons.person_outline;
    case 'app':
      return Icons.phone_android_outlined;
    default:
      return Icons.help_outline;
  }
}

/// Píldora de color con el estado del ticket ("Abierto", "En proceso"...).
class ChipEstadoTicket extends StatelessWidget {
  final String estado;
  const ChipEstadoTicket({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoTicket(estado);
    return Container(
      key: Key('chip_estado_$estado'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        TicketSoporte.etiquetaEstado(estado),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Tiempo relativo corto para la lista ("Ahora", "Hace 5 min", "Ayer").
String tiempoRelativoTicket(DateTime? fecha, {DateTime? ahora}) {
  if (fecha == null) return '';
  final now = ahora ?? DateTime.now();
  final diff = now.difference(fecha);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'Ayer';
  if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
  return fechaCortaTicket(fecha);
}

String _dos(int v) => v.toString().padLeft(2, '0');

String fechaCortaTicket(DateTime d) => '${_dos(d.day)}/${_dos(d.month)}/${d.year}';

/// Hora de un mensaje; con la fecha si no es de hoy.
String horaMensajeTicket(DateTime? d, {DateTime? ahora}) {
  if (d == null) return '';
  final now = ahora ?? DateTime.now();
  final hora = '${_dos(d.hour)}:${_dos(d.minute)}';
  final hoy = d.year == now.year && d.month == now.month && d.day == now.day;
  return hoy ? hora : '${_dos(d.day)}/${_dos(d.month)} $hora';
}

/// Id de un viaje en cualquiera de los formatos que maneja la app
/// (`_id` de `Trip.toJson()` o `id` del backend).
String? idDeViajeTicket(Map<String, dynamic>? viaje) {
  final id = viaje?['_id'] ?? viaje?['id'];
  final s = id?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// "Origen → Destino" del viaje (acepta `origen.direccion` del modelo Trip y
/// `origenDireccion` del ticket).
String rutaDeViajeTicket(Map<String, dynamic>? viaje) {
  if (viaje == null) return '';
  String? dir(dynamic v) {
    if (v is Map) return v['direccion']?.toString();
    return v?.toString();
  }

  final origen = dir(viaje['origen']) ?? viaje['origenDireccion']?.toString();
  final destino = dir(viaje['destino']) ?? viaje['destinoDireccion']?.toString();
  final partes = [origen, destino].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim()).toList();
  return partes.join(' → ');
}

/// "Viaje #12 · Origen → Destino".
String resumenViajeTicket(Map<String, dynamic>? viaje) {
  final id = idDeViajeTicket(viaje);
  final ruta = rutaDeViajeTicket(viaje);
  if (id == null) return ruta;
  return ruta.isEmpty ? 'Viaje #$id' : 'Viaje #$id · $ruta';
}
