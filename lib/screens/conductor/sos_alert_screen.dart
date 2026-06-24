import 'package:flutter/material.dart';
import '../../services/sos_service.dart';

class SOSAlertScreen extends StatefulWidget {
  final String? tripId;
  const SOSAlertScreen({super.key, this.tripId});

  @override
  State<SOSAlertScreen> createState() => _SOSAlertScreenState();
}

class _SOSAlertScreenState extends State<SOSAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _sending = false;
  bool _sent = false;

  static const Color _white = Colors.white;
  static const Color _bgDark = Color(0xFF0D1B2E);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _activateSOS() async {
    setState(() => _sending = true);
    try {
      await SosService.sendAlert(tripId: widget.tripId);
      if (mounted) {
        setState(() => _sent = true);
        _snack('Alerta SOS enviada. Notificando a soporte...');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _sent ? Colors.green : Colors.red.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSOSButton(),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _sent
                        ? 'Alerta enviada.\nSoporte está siendo notificado.'
                        : 'Se enviará tu ubicación\na contactos y soporte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: _white.withValues(alpha: 0.85),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildActivateButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new, size: 20, color: _white),
          ),
          const SizedBox(width: 12),
          Text(
            'Alerta SOS',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200 * _pulseAnimation.value,
              height: 200 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.08),
              ),
            ),
            Container(
              width: 170 * _pulseAnimation.value,
              height: 170 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.12),
              ),
            ),
            Container(
              width: 145 * _pulseAnimation.value,
              height: 145 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.18),
              ),
            ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sent ? Colors.green.shade600 : Colors.red.shade600,
                boxShadow: [
                  BoxShadow(
                    color: (_sent ? Colors.green : Colors.red).withValues(alpha: 0.5),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: _sent
                    ? const Icon(Icons.check, color: Colors.white, size: 48)
                    : const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white, fontSize: 32,
                          fontWeight: FontWeight.w900, letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivateButton() {
    if (_sent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0D1B2E),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Cerrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _sending ? null : _activateSOS,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: _white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _sending
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Activar alerta SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
