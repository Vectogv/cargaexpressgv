import 'package:flutter/material.dart';

class DisputaIniciadaScreen extends StatelessWidget {
  final String motivo;
  final VoidCallback? onVerDetalles;
  final VoidCallback? onChat;
  final VoidCallback? onLlamar;

  const DisputaIniciadaScreen({
    super.key,
    this.motivo = 'La carga llegó dañada',
    this.onVerDetalles,
    this.onChat,
    this.onLlamar,
  });

  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _blue = Color(0xFF1565C0);
  static const Color _inputBorder = Color(0xFFDDDDDD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    _WarningIcon(),
                    const SizedBox(height: 20),
                    const Text(
                      'Disputa iniciada',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _red,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'El cliente ha reportado un problema\ncon la entrega.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Motivo del problema',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _inputBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        motivo,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onVerDetalles,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          disabledBackgroundColor: _divider,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Ver detalles',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _BottomNavBar(onChat: onChat, onLlamar: onLlamar),
          ],
        ),
      ),
    );
  }
}

class _WarningIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(
        painter: _TrianglePainter(),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  static const Color _fill = Color(0xFFFFEBEE);
  static const Color _stroke = Color(0xFFD32F2F);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _fill
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final top = size.height * 0.06;
    final bottom = size.height * 0.94;
    final halfBase = size.width * 0.48;

    final path = Path()
      ..moveTo(cx, top + 4)
      ..lineTo(cx + halfBase, bottom)
      ..lineTo(cx - halfBase, bottom)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomNavBar extends StatelessWidget {
  final VoidCallback? onChat;
  final VoidCallback? onLlamar;

  const _BottomNavBar({this.onChat, this.onLlamar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        color: Colors.white,
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _NavBarItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            onTap: onChat,
          ),
          _NavBarItem(
            icon: Icons.phone_outlined,
            label: 'Llamar',
            onTap: onLlamar,
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: disabled ? const Color(0xFFD1D5DB) : const Color(0xFF555555)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: disabled ? const Color(0xFFD1D5DB) : const Color(0xFF555555),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
