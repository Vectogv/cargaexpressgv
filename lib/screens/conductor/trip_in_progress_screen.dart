import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class TripInProgressScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;
  const TripInProgressScreen({super.key, this.trip});

  @override
  State<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends State<TripInProgressScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  bool _actionLoading = false;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);
  static const Color _white = Colors.white;
  static const Color _activeStep = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    if (widget.trip != null) {
      _trip = widget.trip;
      _loading = false;
    } else {
      _fetchActiveTrip();
    }
  }

  Future<void> _fetchActiveTrip() async {
    try {
      final trip = await ApiClient.instance.getActiveTrip();
      if (mounted) setState(() { _trip = trip; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startTrip() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);
    try {
      await ApiClient.instance.startTrip(_trip!['id']);
      _trip!['estado'] = 'en_curso';
      if (mounted) setState(() {});
      _snack('Viaje iniciado');
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeTrip() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);
    try {
      await ApiClient.instance.completeTrip(_trip!['id']);
      _trip!['estado'] = 'completado';
      if (mounted) setState(() {});
      _snack('Entrega completada');
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _finalizeTrip() async {
    if (_trip == null) return;
    setState(() => _actionLoading = true);
    try {
      await ApiClient.instance.finalizeTrip(_trip!['id']);
      _trip!['estado'] = 'finalizado';
      if (mounted) setState(() {});
      _snack('Viaje finalizado');
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: _bgLight, body: const Center(child: CircularProgressIndicator()));
    }
    if (_trip == null) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(backgroundColor: _white, foregroundColor: _textDark, elevation: 0, title: const Text('Viaje en curso')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No hay viaje activo', style: TextStyle(fontSize: 16, color: Colors.black45)),
          ]),
        ),
      );
    }

    final t = _trip!;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final estado = t['estado'] as String? ?? '';

    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          _buildHeader(context),
          _buildMap(),
          Expanded(child: _buildBottomCard(t, origen, destino, estado)),
          _buildBottomNav(t, estado),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios_new, size: 20, color: _textDark),
          ),
          const SizedBox(width: 12),
          Text('Viaje en curso', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _accentGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _accentGreen.withOpacity(0.4))),
            child: Text('En línea', style: TextStyle(color: _accentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 200,
      color: const Color(0xFFE8EDF2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Mapa en vivo', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            Text('(requiere flutter_map + ubicación)', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard(Map<String, dynamic> t, Map<String, dynamic>? origen, Map<String, dynamic>? destino, String estado) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepper(estado),
            const SizedBox(height: 20),
            _routeRow(Icons.trip_origin, 'Origen', origen?['direccion'] as String? ?? '', Colors.green),
            const SizedBox(height: 8),
            _routeRow(Icons.location_on, 'Destino', destino?['direccion'] as String? ?? '', Colors.red),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _infoChip('Carga', t['carga'] as String? ?? 'N/A'),
              _infoChip('Precio', '\$${(t['precioFinal'] as num? ?? t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}'),
            ]),
            const SizedBox(height: 16),
            _clientSection(t['cliente'] as Map<String, dynamic>?),
            const SizedBox(height: 16),
            if (estado == 'aceptado')
              _actionButton('Iniciar viaje', _startTrip, _primaryDark)
            else if (estado == 'en_curso')
              _actionButton('Completar entrega', _completeTrip, _accentGreen)
            else if (estado == 'completado')
              _actionButton('Finalizar viaje', _finalizeTrip, _primaryBlue)
          ],
        ),
      ),
    );
  }

  Widget _buildStepper(String estado) {
    final steps = ['Aceptado', 'En curso', 'Completado', 'Finalizado'];
    final estados = ['aceptado', 'en_curso', 'completado', 'finalizado'];
    final current = estados.indexOf(estado);
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(height: 2, color: i ~/ 2 < current ? _activeStep : Colors.grey.shade300),
          );
        }
        final idx = i ~/ 2;
        final active = idx <= current;
        return Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: active ? _activeStep : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: idx < current
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${idx + 1}', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );
      }),
    );
  }

  Widget _routeRow(IconData icon, String label, String dir, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        Text(dir, style: const TextStyle(fontWeight: FontWeight.w500)),
      ])),
    ]);
  }

  Widget _infoChip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _textGrey)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _clientSection(Map<String, dynamic>? cliente) {
    if (cliente == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: _primaryDark, child: Text(_initials(cliente['nombre'] as String? ?? ''), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(child: Text(cliente['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
        if (cliente['telefono'] != null)
          IconButton(icon: const Icon(Icons.phone, size: 20), color: _primaryBlue, onPressed: () {}),
      ]),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        onPressed: _actionLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
        ),
        child: _actionLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Widget _buildBottomNav(Map<String, dynamic> t, String estado) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      decoration: const BoxDecoration(color: _white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _navItem(Icons.chat_bubble_outline, 'Chat', () {}),
        _navItem(Icons.phone_outlined, 'Llamar', () {}),
        _navItem(Icons.info_outline, 'Detalle', () {}),
        if (estado == 'aceptado' || estado == 'en_curso')
          _navItem(Icons.cancel_outlined, 'Cancelar', () => _cancelTrip(t)),
      ]),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: _textGrey),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: _textGrey)),
      ]),
    );
  }

  Future<void> _cancelTrip(Map<String, dynamic> t) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Cancelar viaje'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Motivo (opcional)'), maxLines: 2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Sí, cancelar')),
          ],
        );
      },
    );
    if (motivo == null) return;
    try {
      await ApiClient.instance.cancelTrip(t['id'], motivo: motivo.isEmpty ? null : motivo);
      if (mounted) { _snack('Viaje cancelado'); Navigator.pop(context); }
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
