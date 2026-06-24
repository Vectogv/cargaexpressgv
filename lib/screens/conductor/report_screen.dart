import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'trip_in_progress_screen.dart';
import 'offers_screen.dart';
import 'trip_chat_screen.dart';
import 'profile_screen.dart';
import 'disputa_iniciada_wrapper.dart';

class ReportScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;

  const ReportScreen({super.key, this.trip});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _rating = 5;
  final _comentarioCtrl = TextEditingController();
  bool _sending = false;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRatingCard(),
                  const SizedBox(height: 12),
                  _buildMenuCard(Icons.flag_outlined, 'Reportar incidente', () {
                    _snack('Función próximamente disponible');
                  }),
                  const SizedBox(height: 10),
                  _buildMenuCard(Icons.gavel_outlined, 'Abrir disputa', () => _openDispute()),
                  const SizedBox(height: 10),
                  _buildMenuCard(Icons.add_comment_outlined, 'Agregar mi versión', () {
                    _snack('Función próximamente disponible');
                  }),
                  const SizedBox(height: 16),
                  _buildSendButton(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: _primaryDark, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu opinión nos ayuda a mejorar la comunidad.',
                            style: TextStyle(fontSize: 13, color: _primaryDark, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Reportar / Calificar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calificar al cliente', style: TextStyle(fontSize: 14, color: Color(0xFF757575), fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _rating = index + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFC107),
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _rating == 5 ? 'Excelente'
                : _rating == 4 ? 'Muy bueno'
                : _rating == 3 ? 'Bueno'
                : _rating == 2 ? 'Regular' : 'Malo',
            style: TextStyle(fontSize: 14, color: _textGrey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comentarioCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Comentario adicional (opcional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: _textDark),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _sending ? null : _sendRating,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryDark,
          foregroundColor: _white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _sending
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Enviar calificación', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  void _openDispute() async {
    final trip = widget.trip;
    if (trip == null) {
      _snack('No hay viaje activo para abrir una disputa');
      return;
    }
    try {
      final result = await ApiClient.instance.disputeTrip(
        trip['id'],
        motivo: 'Reporte del conductor',
        descripcion: 'Reporte iniciado desde pantalla de reportes',
      );
      final disputeId = result['id'] ?? result['disputeId'];
      if (!mounted || disputeId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DisputaIniciadaWrapper(
            tripId: trip['id'],
            disputeId: disputeId,
            motivo: 'Reporte del conductor',
            origen: (trip['origen'] as Map<String, dynamic>?)?['direccion'] as String? ?? '',
            destino: (trip['destino'] as Map<String, dynamic>?)?['direccion'] as String? ?? '',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack('Error al abrir disputa.');
    }
  }

  Future<void> _sendRating() async {
    final trip = widget.trip;
    if (trip == null) {
      _snack('No hay viaje activo para calificar');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.instance.rateTrip(trip['id'], _rating, comentario: _comentarioCtrl.text.trim());
      if (mounted) {
        _snack('Calificación enviada');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(bottom: 20, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'Inicio', false, () => Navigator.pop(context)),
          _navItem(Icons.local_shipping_outlined, 'Viajes', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TripInProgressScreen()));
          }),
          _navItem(Icons.local_offer_outlined, 'Ofertas', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OffersScreen()));
          }),
          _navItem(Icons.chat_bubble_outline, 'Chat', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TripChatScreen(trip: widget.trip)));
          }),
          _navItem(Icons.person_outline, 'Perfil', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? _primaryDark : _textGrey, size: 24),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isActive ? _primaryDark : _textGrey,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
