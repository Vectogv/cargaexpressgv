import 'package:flutter/material.dart';
import '../../widgets/route_painter.dart';

class LlegadaDestinoScreen extends StatelessWidget {
  final String nombreCliente;
  final double ratingCliente;
  final String? avatarUrl;
  final bool isFinalizando;
  final VoidCallback? onChat;
  final VoidCallback? onLlamar;
  final VoidCallback? onHeLlegado;
  final VoidCallback? onSubirFoto;

  const LlegadaDestinoScreen({
    super.key,
    this.nombreCliente = 'Maria González',
    this.ratingCliente = 4.8,
    this.avatarUrl,
    this.isFinalizando = false,
    this.onChat,
    this.onLlamar,
    this.onHeLlegado,
    this.onSubirFoto,
  });

  static const Color _accentBlue = Color(0xFF2563EB);
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
          _buildMap(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClienteRow(),
                  const SizedBox(height: 16),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'Has llegado al destino.',
                    style: TextStyle(fontSize: 15, color: _textSecondary),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (isFinalizando || onHeLlegado == null) ? null : onHeLlegado,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isFinalizando
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('He llegado al destino',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: (isFinalizando || onSubirFoto == null) ? null : onSubirFoto,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: _accentBlue, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Subir foto de evidencia',
                        style: TextStyle(color: _accentBlue, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return SizedBox(
      height: 260,
      child: CustomPaint(
        size: const Size(double.infinity, 260),
        painter: ArrivalMapPainter(),
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
        GestureDetector(
          onTap: onLlamar,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: onLlamar == null ? _iconDisabled : _divider, width: 1.5),
            ),
            child: Icon(Icons.phone_outlined,
                color: onLlamar == null ? _iconDisabled : _textPrimary, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bottomAction(Icons.chat_bubble_outline_rounded, 'Chat', onChat),
          _bottomAction(Icons.phone_outlined, 'Llamar', onLlamar),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback? onTap) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: disabled ? _iconDisabled : _textPrimary, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: disabled ? _iconDisabled : _textSecondary)),
        ],
      ),
    );
  }
}
