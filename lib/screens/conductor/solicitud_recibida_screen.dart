import 'dart:async';
import 'package:flutter/material.dart';

class SolicitudRecibidaScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final int tiempoExpiracion;

  const SolicitudRecibidaScreen({
    super.key,
    required this.trip,
    this.tiempoExpiracion = 28,
  });

  @override
  State<SolicitudRecibidaScreen> createState() =>
      _SolicitudRecibidaScreenState();
}

class _SolicitudRecibidaScreenState extends State<SolicitudRecibidaScreen> {
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _cardBg = Color(0xFFF9FAFB);

  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.tiempoExpiracion;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        _timer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La solicitud ha expirado')),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getOrigen() {
    final o = widget.trip['origen'];
    if (o is Map) return o['direccion'] as String? ?? '—';
    if (o is String) return o;
    return widget.trip['origen_direccion'] as String? ?? '—';
  }

  String _getDestino() {
    final d = widget.trip['destino'];
    if (d is Map) return d['direccion'] as String? ?? '—';
    if (d is String) return d;
    return widget.trip['destino_direccion'] as String? ?? '—';
  }

  String _getDistancia() {
    final d = widget.trip['distancia'];
    if (d == null) return '—';
    return '${d} km';
  }

  String _getPrecio() {
    final p = widget.trip['precioEstimado'];
    if (p == null) return '—';
    final n = num.tryParse(p.toString());
    if (n == null) return p.toString();
    final s = n.toInt().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '\$${b.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Nueva solicitud de viaje',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildCountdownCard(),
                  const SizedBox(height: 20),
                  _buildTripInfoCard(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    final warning = _secondsRemaining <= 5;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: warning ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE),
        ),
      ),
      color: warning ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              '${_secondsRemaining}',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: warning ? const Color(0xFFDC2626) : _accentBlue,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'segundos para responder',
              style: TextStyle(
                fontSize: 14,
                color: warning ? const Color(0xFFDC2626) : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _divider),
      ),
      color: _cardBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.trip_origin, 'Origen', _getOrigen()),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _divider),
            ),
            _buildInfoRow(Icons.location_on_outlined, 'Destino', _getDestino()),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _divider),
            ),
            _buildInfoRow(Icons.straighten_outlined, 'Distancia estimada',
                _getDistancia()),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _divider),
            ),
            _buildInfoRow(Icons.attach_money_outlined, 'Pago estimado',
                _getPrecio()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: _textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
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
              onPressed: _secondsRemaining > 0
                  ? () => Navigator.of(context).pop('make_offer')
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text(
                'Hacer oferta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _secondsRemaining > 0
                ? () => Navigator.of(context).pop('reject')
                : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text(
              'Rechazar',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
