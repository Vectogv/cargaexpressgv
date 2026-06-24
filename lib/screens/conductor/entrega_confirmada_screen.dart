import 'package:flutter/material.dart';

class EntregaConfirmadaScreen extends StatelessWidget {
  final String nombreCliente;
  final double ratingCliente;
  final String? avatarUrl;
  final String precioAcordado;
  final String comision;
  final String porcentajeComision;
  final String gananciaTotal;
  final VoidCallback? onVerResumen;
  final VoidCallback? onVolverInicio;

  const EntregaConfirmadaScreen({
    super.key,
    this.nombreCliente = 'Maria González',
    this.ratingCliente = 4.8,
    this.avatarUrl,
    this.precioAcordado = '\$55.000',
    this.comision = '- \$5.500',
    this.porcentajeComision = '10%',
    this.gananciaTotal = '\$49.500',
    this.onVerResumen,
    this.onVolverInicio,
  });

  static const Color _green = Color(0xFF16A34A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _star = Color(0xFFF59E0B);
  static const Color _greenDark = Color(0xFF15803D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  _buildClienteCard(),
                  const SizedBox(height: 16),
                  _buildResumenCard(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: _green,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '¡Entrega confirmada!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'El cliente ha confirmado la\nrecepción de la carga.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard() {
    final parts = nombreCliente.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFD1FAE5),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(initials,
                    style: const TextStyle(
                        color: _greenDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 16))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreCliente,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: _star, size: 16),
                  const SizedBox(width: 3),
                  Text(ratingCliente.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildResumenCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFinRow('Precio acordado', precioAcordado,
              valueColor: _textPrimary),
          const Divider(color: _divider, height: 1),
          _buildFinRow('Comisión ($porcentajeComision)', comision,
              valueColor: _textSecondary),
          const Divider(color: _divider, height: 1),
          _buildFinRow('Ganancia total', gananciaTotal,
              labelColor: _green,
              valueColor: _green,
              bold: true),
        ],
      ),
    );
  }

  Widget _buildFinRow(
    String label,
    String value, {
    Color labelColor = const Color(0xFF6B7280),
    Color valueColor = const Color(0xFF111827),
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: labelColor,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  color: valueColor,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onVerResumen,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: _divider,
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text(
                'Ver resumen del viaje',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onVolverInicio,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: _divider, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Volver al inicio',
                style: TextStyle(
                    color: _accentBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
