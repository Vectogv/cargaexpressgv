import 'package:flutter/material.dart';

/// Piezas visuales compartidas por las vistas a pantalla completa del
/// rastreo del cliente (buscando conductor y viaje en curso). Mismo lenguaje
/// que autenticación (`auth_estilos.dart`): tarjetas blancas redondeadas con
/// sombra suave y azul 0xFF2563EB.
class RastreoColores {
  static const primario = Color(0xFF2563EB);
  static const primarioSuave = Color(0xFFEFF4FF);
  static const texto = Color(0xFF1A1A2E);
  static const gris = Color(0xFF6B7280);
  static const borde = Color(0xFFE5E7EB);
  static const fondo = Color(0xFFF5F7FA);
  static const verde = Color(0xFF16A34A);
  static const rojo = Color(0xFFDC2626);
}

const List<BoxShadow> sombraTarjetaRastreo = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4)),
];

/// Barra superior flotante sobre el mapa: atrás (si hay a dónde volver),
/// título y acciones.
class BarraRastreo extends StatelessWidget {
  final String titulo;
  final List<Widget> acciones;

  const BarraRastreo({super.key, required this.titulo, this.acciones = const []});

  @override
  Widget build(BuildContext context) {
    final puedeVolver = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            if (puedeVolver) ...[
              _BotonCircular(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Atrás',
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: sombraTarjetaRastreo,
                ),
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: RastreoColores.texto,
                  ),
                ),
              ),
            ),
            for (final a in acciones) ...[const SizedBox(width: 8), a],
          ],
        ),
      ),
    );
  }
}

class _BotonCircular extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _BotonCircular({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BotonFlotanteRastreo(
      child: IconButton(
        icon: Icon(icon, color: RastreoColores.texto),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Contenedor blanco circular de 48 px con sombra para botones sobre el mapa.
class BotonFlotanteRastreo extends StatelessWidget {
  final Widget child;
  const BotonFlotanteRastreo({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: sombraTarjetaRastreo,
      ),
      child: Center(child: child),
    );
  }
}

/// Marcador de camión para los vehículos cercanos. El backend no envía rumbo
/// (`/api/trips/:id/nearby-drivers` → {lat, lng, tipoVehiculo}): va sin rotar.
class MarcadorCamion extends StatelessWidget {
  final Color color;
  const MarcadorCamion({super.key, this.color = RastreoColores.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.local_shipping_rounded, color: color, size: 18),
    );
  }
}

/// Asa de arrastre de las hojas inferiores.
class AsaHojaRastreo extends StatelessWidget {
  const AsaHojaRastreo({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: RastreoColores.borde,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Título de sección en mayúsculas pequeñas.
class TituloSeccionRastreo extends StatelessWidget {
  final String texto;
  const TituloSeccionRastreo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: RastreoColores.gris,
      ),
    );
  }
}

/// Fila icono + etiqueta + valor (origen, destino, carga...).
class LineaDatoRastreo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? valor;
  final int maxLines;
  const LineaDatoRastreo({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.valor,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final v = (valor ?? '').trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: RastreoColores.gris)),
              const SizedBox(height: 1),
              Text(
                v.isEmpty ? '—' : v,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: RastreoColores.texto,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
