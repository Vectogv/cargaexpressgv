import 'package:flutter/material.dart';
import '../../widgets/route_painter.dart';

class ViajeEnCaminoScreen extends StatelessWidget {
  final String nombreCliente;
  final double ratingCliente;
  final String? avatarUrl;
  final String tiempoEstimado;
  final String distancia;
  final bool isCancelling;
  final VoidCallback? onChat;
  final VoidCallback? onLlamar;
  final VoidCallback? onCancelarViaje;
  final VoidCallback? onBack;

  const ViajeEnCaminoScreen({
    super.key,
    this.nombreCliente = 'Maria González',
    this.ratingCliente = 4.0,
    this.avatarUrl,
    this.tiempoEstimado = '15 min',
    this.distancia = '5.2 km',
    this.isCancelling = false,
    this.onChat,
    this.onLlamar,
    this.onCancelarViaje,
    this.onBack,
  });

  static const Color _primaryBlue = Color(0xFF1A3C6E);
  static const Color _red = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _star = Color(0xFFF59E0B);
  static const Color _greenDark = Color(0xFF15803D);
  static const Color _iconDisabled = Color(0xFFD1D5DB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildMapWithBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  _buildClienteRow(),
                  const SizedBox(height: 16),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 14),
                  _buildStatsRow(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildMapWithBanner() {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: OnTheWayPainter())),
          if (onBack != null)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                bottom: false,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                  onPressed: onBack,
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'En camino al punto de recogida',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A $distancia de distancia',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStat('Tiempo estimado de llegada', tiempoEstimado)),
        Container(width: 1, height: 40, color: _divider),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: _buildStat('Distancia', distancia),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary)),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTextBtn(Icons.chat_bubble_outline_rounded, 'Chat', onChat)),
          Expanded(child: _buildTextBtn(Icons.phone_outlined, 'Llamar', onLlamar)),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: (isCancelling || onCancelarViaje == null) ? null : onCancelarViaje,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _red, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isCancelling
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: _red))
                  : const Text('Cancelar viaje',
                      style: TextStyle(color: _red, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBtn(IconData icon, String label, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: disabled ? _iconDisabled : _textPrimary, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: disabled ? _iconDisabled : _textSecondary)),
        ],
      ),
    );
  }
}
