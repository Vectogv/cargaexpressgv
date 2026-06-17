import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';

class ConductorTripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const ConductorTripDetailScreen({super.key, required this.trip});

  @override
  State<ConductorTripDetailScreen> createState() => _ConductorTripDetailScreenState();
}

class _ConductorTripDetailScreenState extends State<ConductorTripDetailScreen> {
  final _montoCtrl = TextEditingController();
  bool _loading = false;
  bool _offerSent = false;

  static const Color _primaryDark = Color(0xFF1A3C6E);
  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textGrey = Color(0xFF757575);
  static const Color _bgLight = Color(0xFFF5F7FA);

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _makeOffer() async {
    final monto = int.tryParse(_montoCtrl.text.trim());
    if (monto == null || monto <= 0) {
      _snack('Ingresa un monto v\u00e1lido');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient.instance.makeOffer(widget.trip['id'], monto);
      setState(() => _offerSent = true);
      _snack('Oferta enviada exitosamente');
    } catch (e) {
      _snack('Error: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final origen = t['origen'] as Map<String, dynamic>?;
    final destino = t['destino'] as Map<String, dynamic>?;
    final cliente = t['cliente'] as Map<String, dynamic>?;
    final carga = t['carga'] as String? ?? 'No especificada';
    final descripcion = t['descripcion'] as String? ?? '';

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
        title: const Text('Detalle del viaje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRouteCard(origen, destino),
            const SizedBox(height: 12),
            _buildCargoCard(carga, descripcion),
            const SizedBox(height: 12),
            _buildInfoCard(t),
            if (cliente != null) ...[
              const SizedBox(height: 12),
              _buildClientCard(cliente),
            ],
            const SizedBox(height: 12),
            _buildOfferSection(t),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic>? origen, Map<String, dynamic>? destino) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ruta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 12),
          _routePoint(origen?['direccion'] as String? ?? 'Origen', const Color(0xFF1E88E5), 'Direcci\u00f3n de salida'),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: SizedBox(width: 2, height: 24, child: Container(color: const Color(0xFFE0E0E0))),
          ),
          _routePoint(destino?['direccion'] as String? ?? 'Destino', const Color(0xFF4CAF50), 'Direcci\u00f3n de llegada'),
        ],
      ),
    );
  }

  Widget _routePoint(String dir, Color color, String label) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(top: 2),
        width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        const SizedBox(height: 2),
        Text(dir, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }

  Widget _buildCargoCard(String carga, String descripcion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Carga', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _primaryDark.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined, size: 22, color: _primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(carga, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
              if (descripcion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(descripcion, style: TextStyle(fontSize: 13, color: _textGrey)),
                ),
            ])),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informaci\u00f3n del viaje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 12),
          _infoRow('Presupuesto del cliente', '\$${(t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}'),
          _infoRow('Distancia', '${(t['distancia'] as num?)?.toStringAsFixed(1) ?? '?'} km'),
          if (t['tiempoEstimado'] != null)
            _infoRow('Tiempo estimado', '${t['tiempoEstimado']} min'),
          _infoRow('Publicado', _formatDate(t['createdAt'] as String?)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: _textGrey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> cliente) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cliente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _primaryDark,
              child: Text(
                _initials(cliente['nombre'] as String? ?? ''),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cliente['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (cliente['calificacion'] != null)
                Row(children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFFF8F00)),
                  const SizedBox(width: 4),
                  Text('${cliente['calificacion']}', style: const TextStyle(fontSize: 13, color: _textGrey)),
                ]),
            ])),
          ]),
        ],
      ),
    );
  }

  Widget _buildOfferSection(Map<String, dynamic> t) {
    if (_offerSent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _accentGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _accentGreen.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.check_circle, color: _accentGreen, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Oferta enviada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _accentGreen)),
              Text('Espera a que el cliente revise tu propuesta', style: TextStyle(fontSize: 13, color: _textGrey)),
            ]),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.payments_outlined, size: 20, color: _primaryBlue),
            ),
            const SizedBox(width: 10),
            const Text('Tu oferta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
          ]),
          const SizedBox(height: 6),
          Text('Ingresa el monto por el que har\u00edas este viaje', style: TextStyle(fontSize: 12, color: _textGrey)),
          const SizedBox(height: 12),
          TextField(
            controller: _montoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixText: '\$ ',
              hintText: '0',
              hintStyle: TextStyle(color: Colors.grey.shade300),
              filled: true,
              fillColor: _bgLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.info_outline, size: 14, color: _textGrey),
            const SizedBox(width: 6),
            Text('Presupuesto del cliente: \$${(t['precioEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}', style: TextStyle(fontSize: 12, color: _textGrey)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _makeOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Enviar oferta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
