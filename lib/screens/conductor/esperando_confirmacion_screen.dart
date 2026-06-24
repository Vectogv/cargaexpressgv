import 'package:flutter/material.dart';
import '../../widgets/route_painter.dart';

class EsperandoConfirmacionScreen extends StatelessWidget {
  final VoidCallback? onChat;
  final VoidCallback? onLlamar;
  final int? segundosRestantes;

  const EsperandoConfirmacionScreen({
    super.key,
    this.onChat,
    this.onLlamar,
    this.segundosRestantes,
  });

  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _iconDisabled = Color(0xFFD1D5DB);
  static const Color _countdownNormal = Color(0xFF2563EB);
  static const Color _countdownWarning = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIllustration(),
                      const SizedBox(height: 32),
                      const Text(
                        'Esperando confirmación\ndel cliente',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'El cliente ha sido notificado de tu llegada. Por favor espera mientras verifica la carga.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: _textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Puedes contactarlo por chat\no llamada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: _textSecondary,
                          height: 1.6,
                        ),
                      ),
                      if (segundosRestantes != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          '${segundosRestantes!}s',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: segundosRestantes! < 10
                                ? _countdownWarning
                                : _countdownNormal,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'tiempo restante',
                          style: TextStyle(
                            fontSize: 13,
                            color: segundosRestantes! < 10
                                ? _countdownWarning
                                : _textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(painter: ConfirmationIllustrationPainter()),
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
