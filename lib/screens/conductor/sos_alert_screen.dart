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
  String? _selectedMotivo;
  final _detalleCtrl = TextEditingController();
  bool _showForm = true;

  static const Color _white = Colors.white;
  static const Color _bgDark = Color(0xFF0D1B2E);
  static const Color _inputFill = Color(0xFF1B2D44);

  static const List<String> _motivos = [
    'Robo/Amenaza',
    'Accidente',
    'Cliente agresivo',
    'Otro',
  ];

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
    _detalleCtrl.dispose();
    super.dispose();
  }

  Future<void> _activateSOS() async {
    if (_selectedMotivo == null) return;
    setState(() => _sending = true);
    try {
      final detalles = _detalleCtrl.text.trim();
      await SosService.sendAlert(
        tripId: widget.tripId,
        motivo: _selectedMotivo,
        detalles: detalles.isNotEmpty ? detalles : null,
      );
      if (mounted) {
        setState(() {
          _sent = true;
          _showForm = false;
        });
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_showForm) ...[
                    _buildMotivoSelection(),
                    const SizedBox(height: 16),
                    _buildDetalleField(),
                    const SizedBox(height: 24),
                    _buildSOSButton(),
                  ] else ...[
                    const SizedBox(height: 60),
                    _buildSOSButton(),
                  ],
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _sent
                          ? 'Alerta enviada.\nSoporte está siendo notificado.'
                          : 'Selecciona el tipo de emergencia\ny activa la alerta.',
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
          ),
          _buildActivateButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMotivoSelection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de emergencia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._motivos.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedMotivo = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedMotivo == m
                      ? Colors.red.withValues(alpha: 0.2)
                      : _inputFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedMotivo == m
                        ? Colors.red.shade400
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedMotivo == m
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _selectedMotivo == m
                          ? Colors.red.shade400
                          : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      m,
                      style: TextStyle(
                        color: _selectedMotivo == m ? Colors.white : Colors.white70,
                        fontWeight: _selectedMotivo == m ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDetalleField() {
    if (_selectedMotivo == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextField(
        controller: _detalleCtrl,
        maxLines: 3,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Describe la situación (opcional)',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          filled: true,
          fillColor: _inputFill,
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
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
          onPressed: (_sending || _selectedMotivo == null) ? null : _activateSOS,
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
