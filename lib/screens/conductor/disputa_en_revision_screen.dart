import 'package:flutter/material.dart';

class DisputaEnRevisionScreen extends StatelessWidget {
  final String origen;
  final String destino;
  final VoidCallback? onVerDetalles;

  const DisputaEnRevisionScreen({
    super.key,
    this.origen = 'Av. Principal, Caracas',
    this.destino = 'Valencia, Zona Industrial',
    this.onVerDetalles,
  });

  static const Color _textPrimary = Color(0xFF111111);
  static const Color _textSecondary = Color(0xFF555555);
  static const Color _label = Color(0xFF888888);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Disputa en revisión',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: _textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estado actual',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _label,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'En revisión',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: _divider, height: 1),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Te notificaremos cuando haya\nuna resolución.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Divider(color: _divider, height: 1),
              const SizedBox(height: 20),
              const Text(
                'Información del viaje',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _TripInfoRow(label: 'Origen', value: origen),
              const SizedBox(height: 4),
              const Divider(color: Color(0xFFF2F2F2), height: 1),
              const SizedBox(height: 12),
              _TripInfoRow(label: 'Destino', value: destino),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: onVerDetalles,
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled) ? _divider : _blue,
                    ),
                    side: WidgetStateProperty.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.disabled) ? _divider : _blue,
                        width: 1.5,
                      ),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  child: const Text(
                    'Ver detalles',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _TripInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111111),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
