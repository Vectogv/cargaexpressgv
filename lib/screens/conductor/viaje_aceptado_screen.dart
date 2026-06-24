import 'package:flutter/material.dart';
import '../../widgets/route_painter.dart';

class ViajeAceptadoScreen extends StatelessWidget {
  final String nombreCliente;
  final double ratingCliente;
  final String? avatarUrl;
  final String origen;
  final String destino;
  final String precioAcordado;
  final bool isStarting;
  final bool isCancelling;
  final VoidCallback? onLlamar;
  final VoidCallback? onMensaje;
  final VoidCallback? onIniciarViaje;
  final VoidCallback? onCancelarViaje;

  const ViajeAceptadoScreen({
    super.key,
    this.nombreCliente = 'Maria González',
    this.ratingCliente = 4.8,
    this.avatarUrl,
    this.origen = 'Av. Principal, Caracas',
    this.destino = 'Valencia, Zona Industrial',
    this.precioAcordado = '\$55.000',
    this.isStarting = false,
    this.isCancelling = false,
    this.onLlamar,
    this.onMensaje,
    this.onIniciarViaje,
    this.onCancelarViaje,
  });

  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _red = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _star = Color(0xFFF59E0B);
  static const Color _greenDark = Color(0xFF15803D);
  static const Color _iconDisabled = Color(0xFFD1D5DB);

  bool get _busy => isStarting || isCancelling;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildMapSection(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  _buildClienteRow(),
                  const SizedBox(height: 16),
                  const Divider(color: _divider, height: 1),
                  _buildInfoRow('Origen', origen),
                  const Divider(color: _divider, height: 1),
                  _buildInfoRow('Destino', destino),
                  const Divider(color: _divider, height: 1),
                  _buildPrecioRow(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Viaje aceptado',
        style: TextStyle(color: Color(0xFF111827), fontSize: 17, fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF111827), size: 28),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: 220,
      child: ClipRect(
        child: CustomPaint(
          size: const Size(double.infinity, 220),
          painter: RoutePainter(),
        ),
      ),
    );
  }

  Widget _buildClienteRow() {
    final parts = nombreCliente.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFD1FAE5),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(initials,
                  style: const TextStyle(color: _greenDark, fontWeight: FontWeight.w700, fontSize: 16))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreCliente,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: _star, size: 16),
                  const SizedBox(width: 3),
                  Text(ratingCliente.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                ],
              ),
            ],
          ),
        ),
        _buildActionIcon(Icons.phone_outlined, onLlamar),
        const SizedBox(width: 10),
        _buildActionIcon(Icons.chat_bubble_outline_rounded, onMensaje),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: disabled ? _iconDisabled : _divider, width: 1.5),
        ),
        child: Icon(icon, color: disabled ? _iconDisabled : _textPrimary, size: 20),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPrecioRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Precio acordado', style: TextStyle(fontSize: 13, color: _textSecondary)),
          Text(precioAcordado,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_busy || onIniciarViaje == null) ? null : onIniciarViaje,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isStarting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Iniciar viaje',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (_busy || onCancelarViaje == null) ? null : onCancelarViaje,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: _red, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isCancelling
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _red))
                  : const Text('Cancelar viaje',
                      style: TextStyle(color: _red, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
