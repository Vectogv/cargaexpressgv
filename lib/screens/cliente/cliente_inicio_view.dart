import 'package:flutter/material.dart';

import '../../contracts/trip_status.dart';

const Color _kPrimary = Color(0xFF2563EB);
const Color _kTexto = Color(0xFF1A1A2E);
const Color _kGris = Color(0xFF6B7280);
const Color _kBorde = Color(0xFFE5E7EB);

/// Color del estado de un viaje para chips y tarjetas.
Color colorEstadoViaje(String? estado) {
  switch (estado) {
    case TripStatus.buscando:
    case TripStatus.pendiente:
    case TripStatus.creado:
      return const Color(0xFFF59E0B);
    case TripStatus.aceptado:
    case TripStatus.enCamino:
    case TripStatus.llegada:
    case TripStatus.enCurso:
      return _kPrimary;
    case TripStatus.entregado:
    case TripStatus.esperaConfirmacion:
    case TripStatus.pendienteConfirmacion:
    case TripStatus.finalizado:
      return const Color(0xFF16A34A);
    case TripStatus.disputa:
    case TripStatus.enDisputa:
      return const Color(0xFFD97706);
    case TripStatus.cancelado:
    case TripStatus.rechazado:
    case TripStatus.sos:
      return const Color(0xFFDC2626);
    default:
      return _kGris;
  }
}

/// Contenido del inicio del cliente (sin lógica: [ClienteHomeScreen] carga
/// los datos y navega).
class ClienteInicioView extends StatelessWidget {
  final String? nombre;
  final bool cargando;
  final bool errorActivo;
  final Map<String, dynamic>? viajeActivo;
  final List<Map<String, dynamic>> recientes;
  final bool cargandoRecientes;
  final bool errorRecientes;
  final VoidCallback onNuevoEnvio;
  final VoidCallback onVerSeguimiento;
  final ValueChanged<Map<String, dynamic>> onVerViaje;
  final VoidCallback onHistorial;
  final VoidCallback onPerfil;
  final VoidCallback onSoporte;
  final VoidCallback onReintentar;
  final Future<void> Function() onRefresh;

  const ClienteInicioView({
    super.key,
    required this.nombre,
    required this.cargando,
    required this.errorActivo,
    required this.viajeActivo,
    required this.recientes,
    required this.cargandoRecientes,
    required this.errorRecientes,
    required this.onNuevoEnvio,
    required this.onVerSeguimiento,
    required this.onVerViaje,
    required this.onHistorial,
    required this.onPerfil,
    required this.onSoporte,
    required this.onReintentar,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final primerNombre = (nombre ?? '').trim().split(' ').first;
    final activo = viajeActivo;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            primerNombre.isEmpty ? '¡Hola!' : '¡Hola, $primerNombre!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _kTexto, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          Text(
            activo != null ? 'Tienes un viaje en marcha.' : '¿Qué vas a enviar hoy?',
            style: const TextStyle(fontSize: 15, color: _kGris),
          ),
          const SizedBox(height: 20),
          if (cargando)
            const _CargandoCard()
          else ...[
            if (errorActivo) ...[
              _AvisoError(
                texto: 'No pudimos verificar si tienes un viaje activo. Revisa tu conexión.',
                onReintentar: onReintentar,
              ),
              const SizedBox(height: 16),
            ],
            if (activo != null)
              _ViajeActivoCard(viaje: activo, onTap: onVerSeguimiento)
            else
              _NuevoEnvioCard(onTap: onNuevoEnvio),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _Acceso(icon: Icons.receipt_long_outlined, label: 'Mis envíos', onTap: onHistorial)),
              const SizedBox(width: 10),
              Expanded(child: _Acceso(icon: Icons.person_outline_rounded, label: 'Perfil', onTap: onPerfil)),
              const SizedBox(width: 10),
              Expanded(child: _Acceso(icon: Icons.support_agent, label: 'Soporte', onTap: onSoporte)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text('Envíos recientes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kTexto)),
              ),
              if (recientes.isNotEmpty)
                TextButton(onPressed: onHistorial, child: const Text('Ver todos')),
            ],
          ),
          const SizedBox(height: 8),
          if (cargandoRecientes)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            )
          else if (errorRecientes)
            _AvisoError(texto: 'No pudimos cargar tus envíos.', onReintentar: onReintentar)
          else if (recientes.isEmpty)
            const _SinEnvios()
          else
            for (final v in recientes) ...[
              _ViajeRecienteTile(viaje: v, onTap: () => onVerViaje(v)),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CargandoCard extends StatelessWidget {
  const _CargandoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(18)),
      alignment: Alignment.center,
      child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}

class _NuevoEnvioCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NuevoEnvioCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kPrimary,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        key: const Key('btn_nuevo_envio'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nuevo envío', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                      'Indica origen, destino y tu oferta. Te conectamos con conductores cercanos.',
                      style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViajeActivoCard extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onTap;
  const _ViajeActivoCard({required this.viaje, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estado = viaje['estado'] as String?;
    final origen = viaje['origen'];
    final destino = viaje['destino'];
    final conductor = viaje['conductor'];
    final color = colorEstadoViaje(estado);
    final enDisputa = estado == TripStatus.disputa || estado == TripStatus.enDisputa;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('card_viaje_activo'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('VIAJE ACTIVO', maxLines: 1, style: TextStyle(fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: _kGris)),
                  ),
                  Flexible(flex: 2, child: _ChipEstado(estado: estado)),
                ],
              ),
              const SizedBox(height: 14),
              _LineaRuta(icon: Icons.trip_origin, color: const Color(0xFF16A34A), texto: origen is Map ? origen['direccion']?.toString() : null),
              const SizedBox(height: 8),
              _LineaRuta(icon: Icons.location_on, color: const Color(0xFFDC2626), texto: destino is Map ? destino['direccion']?.toString() : null),
              if (conductor is Map && (conductor['nombre']?.toString().isNotEmpty ?? false)) ...[
                const Divider(height: 24, color: _kBorde),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFEFF4FF),
                      child: Text(
                        _iniciales(conductor['nombre'].toString()),
                        style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(conductor['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kTexto)),
                          Text(
                            [conductor['tipoVehiculo'], conductor['placa']]
                                .where((e) => e != null && e.toString().isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(fontSize: 12, color: _kGris),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(enDisputa ? Icons.gavel_rounded : Icons.map_outlined, size: 20),
                  label: Text(enDisputa ? 'Ver estado del caso' : 'Ver seguimiento',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _iniciales(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

class _ChipEstado extends StatelessWidget {
  final String? estado;
  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = colorEstadoViaje(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        TripStatus.label(estado),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _LineaRuta extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? texto;
  const _LineaRuta({required this.icon, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    final t = (texto ?? '').trim();
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t.isEmpty ? '—' : t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: _kTexto),
          ),
        ),
      ],
    );
  }
}

class _Acceso extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Acceso({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F7FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: _kPrimary, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTexto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViajeRecienteTile extends StatelessWidget {
  final Map<String, dynamic> viaje;
  final VoidCallback onTap;
  const _ViajeRecienteTile({required this.viaje, required this.onTap});

  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  static String _fecha(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    return '${dt.day} ${_meses[dt.month - 1]} · ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final estado = viaje['estado'] as String?;
    final origen = viaje['origen'];
    final destino = viaje['destino'];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: _ChipEstado(estado: estado)),
                  const SizedBox(width: 8),
                  const Spacer(),
                  Text(_fecha(viaje['createdAt']?.toString()), style: const TextStyle(fontSize: 12, color: _kGris)),
                ],
              ),
              const SizedBox(height: 10),
              _LineaRuta(icon: Icons.trip_origin, color: const Color(0xFF16A34A), texto: origen is Map ? origen['direccion']?.toString() : null),
              const SizedBox(height: 6),
              _LineaRuta(icon: Icons.location_on, color: const Color(0xFFDC2626), texto: destino is Map ? destino['direccion']?.toString() : null),
            ],
          ),
        ),
      ),
    );
  }
}

class _SinEnvios extends StatelessWidget {
  const _SinEnvios();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorde),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFFBFC5CD)),
          SizedBox(height: 10),
          Text('Aún no tienes envíos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTexto)),
          SizedBox(height: 4),
          Text(
            'Cuando solicites uno, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kGris),
          ),
        ],
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String texto;
  final VoidCallback onReintentar;
  const _AvisoError({required this.texto, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFC2410C)),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13, color: Color(0xFF7C2D12)))),
          TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
